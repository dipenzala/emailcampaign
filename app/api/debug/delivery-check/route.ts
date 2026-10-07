import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { decrypt } from '@/lib/crypto';
import { oauthClient } from '@/lib/gmail';
import { google } from 'googleapis';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function GET(req: Request) {
  try {
    const url = new URL(req.url);
    const campaignId = url.searchParams.get('campaignId');

    // Get campaign
    let campaign: any = null;
    if (campaignId) {
      campaign = await prisma.campaign.findUnique({ where: { id: campaignId } });
    } else {
      campaign = await prisma.campaign.findFirst({ orderBy: { createdAt: 'desc' } });
    }

    if (!campaign) {
      return NextResponse.json({ ok: false, error: 'No campaign' });
    }

    // ═══════════════════════════════════════════
    // COUNTER BUG CHECK
    // ═══════════════════════════════════════════
    const actualSent = await prisma.campaignRecipient.count({
      where: { campaignId: campaign.id, status: 'SENT' },
    });
    const actualTotal = await prisma.campaignRecipient.count({
      where: { campaignId: campaign.id },
    });
    const actualFailed = await prisma.campaignRecipient.count({
      where: { campaignId: campaign.id, status: 'FAILED' },
    });

    const counterBug = {
      campaignStoredSent: campaign.sentCount,
      campaignStoredTotal: campaign.totalCount,
      actualSent,
      actualTotal,
      actualFailed,
      hasBug: campaign.sentCount > campaign.totalCount || campaign.sentCount !== actualSent,
    };

    // ═══════════════════════════════════════════
    // SAMPLE EMAILS — verify via Gmail API
    // ═══════════════════════════════════════════
    const samples = await prisma.campaignRecipient.findMany({
      where: { campaignId: campaign.id, status: 'SENT' },
      include: { contact: true, senderAccount: true },
      take: 5,
      orderBy: { sentAt: 'desc' },
    });

    const verification: any[] = [];

    for (const s of samples) {
      const check: any = {
        email: s.contact.email,
        sentAt: s.sentAt,
        sender: s.senderAccount?.email || 'unknown',
        providerMessageId: s.providerMessageId,
        existsInGmail: false,
        gmailLabels: [],
        error: null,
      };

      if (s.providerMessageId && s.senderAccount) {
        try {
          const access = s.senderAccount.accessToken ? decrypt(s.senderAccount.accessToken) : '';
          const refresh = s.senderAccount.refreshToken ? decrypt(s.senderAccount.refreshToken) : '';
          const c = oauthClient();
          c.setCredentials({ access_token: access, refresh_token: refresh });
          const gmail = google.gmail({ version: 'v1', auth: c });

          const msg = await gmail.users.messages.get({
            userId: 'me',
            id: s.providerMessageId,
            format: 'minimal',
          });

          check.existsInGmail = true;
          check.gmailLabels = msg.data.labelIds || [];
          check.gmailSnippet = msg.data.snippet?.slice(0, 80);
        } catch (e: any) {
          check.error = e.message?.slice(0, 200);
        }
      }

      verification.push(check);
    }

    // ═══════════════════════════════════════════
    // BOUNCE CHECK — look for mailer-daemon in inbox
    // ═══════════════════════════════════════════
    let bounceCount = 0;
    let recentBounces: any[] = [];

    try {
      const sender = await prisma.senderAccount.findFirst({
        where: { status: 'CONNECTED', refreshToken: { not: null } },
      });

      if (sender) {
        const access = sender.accessToken ? decrypt(sender.accessToken) : '';
        const refresh = decrypt(sender.refreshToken!);
        const c = oauthClient();
        c.setCredentials({ access_token: access, refresh_token: refresh });
        const gmail = google.gmail({ version: 'v1', auth: c });

        // Search for bounces from mailer-daemon
        const bounces = await gmail.users.messages.list({
          userId: 'me',
          q: 'from:mailer-daemon OR from:postmaster OR subject:undelivered OR subject:undeliverable',
          maxResults: 20,
        });

        bounceCount = bounces.data.messages?.length || 0;

        for (const m of (bounces.data.messages || []).slice(0, 5)) {
          if (!m.id) continue;
          try {
            const msg = await gmail.users.messages.get({
              userId: 'me',
              id: m.id,
              format: 'minimal',
            });
            recentBounces.push({
              id: m.id,
              snippet: msg.data.snippet?.slice(0, 150),
              labels: msg.data.labelIds,
            });
          } catch {}
        }
      }
    } catch (e: any) {
      recentBounces = [{ error: e.message?.slice(0, 100) }];
    }

    return NextResponse.json({
      ok: true,
      campaign: {
        id: campaign.id,
        name: campaign.name,
        subject: campaign.subject,
        status: campaign.status,
      },
      counterBug,
      verification,
      bounceCheck: {
        bounceCount,
        recentBounces,
      },
      diagnosis: {
        counterBugFound: counterBug.hasBug,
        sampleVerified: verification.filter(v => v.existsInGmail).length,
        sampleFailed: verification.filter(v => !v.existsInGmail).length,
      },
    });
  } catch (err: any) {
    return NextResponse.json({ ok: false, error: err.message }, { status: 500 });
  }
}
