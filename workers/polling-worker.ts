import 'dotenv/config';
import { prisma } from '../lib/prisma';
import { decrypt, encrypt } from '../lib/crypto';
import { oauthClient } from '../lib/gmail';
import { google } from 'googleapis';
import { buildMime, htmlToText } from '../lib/mime';
import { renderTemplate } from '../lib/personalization';
import { pickNextSenderStrict, markSenderUsed } from '../lib/sender-rotation';
import { handleBounce } from '../lib/bounce-handler';

// Inject tracking pixel into HTML
function injectTrackingPixel(html: string, recipientId: string, appUrl: string): string {
  const pixelUrl = `${appUrl}/api/track/open/${recipientId}`;
  const pixel = `<img src="${pixelUrl}" width="1" height="1" style="display:none" alt="" />`;
  if (/<\/body>/i.test(html)) {
    return html.replace(/<\/body>/i, `${pixel}</body>`);
  }
  return html + pixel;
}

const POLL_INTERVAL = 3000;
const BATCH_SIZE = 5;

let running = true;
let processing = false;

async function sendViaGmail(sender: any, to: string, subject: string, html: string, text: string, unsubUrl?: string) {
  const access = sender.accessToken ? decrypt(sender.accessToken) : '';
  const refresh = decrypt(sender.refreshToken!);
  const c = oauthClient();
  c.setCredentials({ access_token: access, refresh_token: refresh });
  const gmail = google.gmail({ version: 'v1', auth: c });

  const raw = buildMime({
    from: `${sender.displayName ?? sender.email} <${sender.email}>`,
    to, subject, html, text, unsubscribeUrl: unsubUrl,
  });

  const res = await gmail.users.messages.send({
    userId: 'me',
    requestBody: { raw: Buffer.from(raw).toString('base64url') },
  });

  return { id: res.data.id, access, refresh };
}

async function processOne(recipient: any) {
  const { id: recipientId, campaignId } = recipient;

  const campaign = await prisma.campaign.findUnique({ where: { id: campaignId } });
  if (!campaign) return false;
  if (campaign.status !== 'RUNNING') return false;

  // Suppression check
  const sup = await prisma.suppressionList.findUnique({ where: { email: recipient.contact.email } });
  if (sup) {
    await prisma.campaignRecipient.update({
      where: { id: recipientId },
      data: { status: 'SUPPRESSED', errorCode: 'SUPPRESSED', errorMessage: sup.reason },
    });
    await prisma.campaign.update({
      where: { id: campaignId },
      data: { suppressedCount: { increment: 1 } },
    });
    console.log(`⏭️  SKIP ${recipient.contact.email} (suppressed)`);
    return true;
  }

  // Mark processing
  await prisma.campaignRecipient.update({
    where: { id: recipientId },
    data: { status: 'PROCESSING', attemptCount: recipient.attemptCount + 1 },
  });

  // ============ STRICT ROTATION ============
  const sender = await pickNextSenderStrict({
    batchLimit: campaign.batchLimit ?? 10,
  });

  if (!sender) {
    console.log('⏸️  No sender available — all at cap');
    await prisma.campaignRecipient.update({
      where: { id: recipientId },
      data: { status: 'QUEUED' },
    });
    return false;
  }

  console.log(`📤 [Sender: ${sender.email}] batch=${sender.batchCount}/${campaign.batchLimit ?? 10} sent=${sender.sentToday}/${sender.dailyLimit}`);

  const unsubUrl = `${process.env.APP_URL}/api/unsubscribe/${Buffer.from(recipient.contact.email).toString('base64url')}`;
  let personalizedHtml = renderTemplate(campaign.html, {
    name: recipient.contact.name ?? '',
    email: recipient.contact.email,
    company: recipient.contact.company ?? '',
    city: recipient.contact.city ?? '',
    phone: recipient.contact.phone ?? '',
  });
  personalizedHtml = injectTrackingPixel(personalizedHtml, recipient.id, process.env.APP_URL || );
  const text = htmlToText(personalizedHtml);

  try {
    const { id: providerMessageId, access, refresh } = await sendViaGmail(
      sender, recipient.contact.email, campaign.subject, personalizedHtml, text, unsubUrl
    );

    await prisma.campaignRecipient.update({
      where: { id: recipientId },
      data: {
        status: 'SENT',
        senderAccountId: sender.id,
        providerMessageId,
        sentAt: new Date(),
        errorCode: null,
        errorMessage: null,
      },
    });

    await prisma.campaign.update({
      where: { id: campaignId },
      data: { sentCount: { increment: 1 } },
    });

    await markSenderUsed(sender.id);

    if (access && refresh) {
      await prisma.senderAccount.update({
        where: { id: sender.id },
        data: { accessToken: encrypt(access), refreshToken: encrypt(refresh) },
      });
    }

    console.log(`✅ SENT [${sender.email}] → ${recipient.contact.email}`);

    const remaining = await prisma.campaignRecipient.count({
      where: { campaignId, status: { in: ['QUEUED', 'PROCESSING'] } },
    });
    if (remaining === 0) {
      await prisma.campaign.update({
        where: { id: campaignId },
        data: { status: 'COMPLETED', completedAt: new Date() },
      });
      console.log('🎉 CAMPAIGN COMPLETED');
    }

    return true;
  } catch (err: any) {
    const msg = err?.message ?? 'Send failed';
    const code = err?.code ?? err?.response?.status ?? 'ERROR';
    const isBounce = /550|551|552|553|554|5\.1\.1|user unknown|mailbox|invalid recipient/i.test(msg);
    const isPerm = /insufficient|permission|invalid_grant|unauthorized/i.test(msg);

    if (isBounce || isPerm) {
      await prisma.suppressionList.upsert({
        where: { email: recipient.contact.email },
        create: { email: recipient.contact.email, reason: isBounce ? 'BOUNCED' : 'MANUAL_BLOCK' },
        update: {},
      }).catch(() => {});
      await prisma.campaignRecipient.update({
        where: { id: recipientId },
        data: {
          status: isBounce ? 'BOUNCED' : 'SUPPRESSED',
          errorCode: isBounce ? 'BOUNCED' : 'AUTO_SUPPRESSED',
          errorMessage: msg.slice(0, 200),
          failedAt: new Date(),
        },
      });
      await prisma.campaign.update({
        where: { id: campaignId },
        data: { failedCount: { increment: 1 } },
      });
      if (isBounce) await handleBounce({ email: recipient.contact.email, senderAccountId: sender.id, bounceType: 'HARD' });
      console.log(`⛔ ${isBounce ? 'BOUNCED' : 'SUPPRESSED'} ${recipient.contact.email}`);
      return false;
    }

    // Retryable
    if (recipient.attemptCount < 3) {
      await prisma.campaignRecipient.update({
        where: { id: recipientId },
        data: { status: 'QUEUED', errorMessage: msg.slice(0, 200) },
      });
    } else {
      await prisma.campaignRecipient.update({
        where: { id: recipientId },
        data: { status: 'FAILED', errorCode: String(code), errorMessage: msg.slice(0, 200), failedAt: new Date() },
      });
      await prisma.campaign.update({
        where: { id: campaignId },
        data: { failedCount: { increment: 1 } },
      });
    }
    console.log(`❌ ${recipient.contact.email}: ${msg.slice(0, 60)}`);
    return false;
  }
}

async function poll() {
  if (!running || processing) return;
  processing = true;

  try {
    const recips = await prisma.campaignRecipient.findMany({
      where: {
        status: 'QUEUED',
        campaign: { status: 'RUNNING' },
      },
      include: { contact: true },
      take: BATCH_SIZE,
      orderBy: { queuedAt: 'asc' },
    });

    if (recips.length > 0) {
      console.log(`\n📬 ${recips.length} queued`);
      for (const r of recips) {
        if (!running) break;
        await processOne(r);
      }
    }
  } catch (e: any) {
    console.error('Poll error:', e.message);
  } finally {
    processing = false;
  }
}

// ============ START ============
console.log('');
console.log('═══════════════════════════════════════════');
console.log(' 🔄 STRICT ROTATION WORKER');
console.log('═══════════════════════════════════════════');
console.log('   Poll:       ' + (POLL_INTERVAL / 1000) + 's');
console.log('   Batch size: ' + BATCH_SIZE);
console.log('   Mode:       Sender 1 → Sender 2 → Sender 3 → ...');
console.log('');
console.log('🎯 Listening for QUEUED recipients...');
console.log('');

poll();
setInterval(poll, POLL_INTERVAL);

process.on('SIGINT', async () => {
  console.log('\n🛑 Shutting down...');
  running = false;
  await prisma.$disconnect();
  process.exit(0);
});
