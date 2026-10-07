import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { decrypt } from '@/lib/crypto';
import { oauthClient } from '@/lib/gmail';
import { google } from 'googleapis';
import { buildMime, htmlToText } from '@/lib/mime';
import { renderTemplate, formatSubject } from '@/lib/personalization';
import { checkEmail } from '@/lib/spam-checker';
import crypto from 'crypto';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";
export const maxDuration = 60;

export async function POST(req: Request, { params }: { params: { id: string } }) {
  try {
    const { approvalEmail } = await req.json();
    if (!approvalEmail || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(approvalEmail)) {
      return NextResponse.json({ error: 'Valid approval email required' }, { status: 400 });
    }

    const campaign = await prisma.campaign.findUnique({ where: { id: params.id } });
    if (!campaign) {
      return NextResponse.json({ error: 'Campaign not found' }, { status: 404 });
    }

    // Spam check
    const sender = await prisma.senderAccount.findFirst({ where: { status: 'CONNECTED' } });
    const report = checkEmail({
      subject: campaign.subject,
      html: campaign.html,
      fromEmail: sender?.email || 'noreply@example.com',
    });

    if (report.blocked) {
      return NextResponse.json(
        { error: 'Spam score too high — fix content first', score: report.score, issues: report.issues },
        { status: 400 }
      );
    }

    if (!sender || !sender.refreshToken) {
      return NextResponse.json({ error: 'No connected sender' }, { status: 400 });
    }

    // Generate approval token
    const token = crypto.randomBytes(24).toString('hex');

    // Get sample recipient (first queued)
    const sampleRecipient = await prisma.campaignRecipient.findFirst({
      where: { campaignId: params.id, status: 'QUEUED' },
      include: { contact: true },
    });

    const sampleData = sampleRecipient?.contact ? {
      name: sampleRecipient.contact.name || '',
      email: sampleRecipient.contact.email,
      company: sampleRecipient.contact.company || '',
      city: sampleRecipient.contact.city || '',
      phone: sampleRecipient.contact.phone || '',
    } : {
      name: 'Sample Name',
      email: 'sample@example.com',
      company: 'Sample Company',
      city: '',
      phone: '',
    };

    // Render sample email
    const finalSubject = formatSubject(campaign.subject, sampleData);
    let sampleHtml = renderTemplate(campaign.html, sampleData);

    // Add approval banner at top
    const approveUrl = `${process.env.APP_URL}/approve/${token}`;
    const approvalBanner = `
<div style="background:#f0fdf4;border:2px dashed #10b981;border-radius:12px;padding:20px;margin:20px;font-family:Arial,sans-serif;">
  <div style="font-size:16px;font-weight:800;color:#065f46;margin-bottom:8px;">
    🔍 This is a TEST email for approval
  </div>
  <div style="font-size:13px;color:#047857;line-height:1.6;margin-bottom:16px;">
    Campaign: <b>${campaign.name}</b><br>
    Total recipients: <b>${campaign.totalCount}</b><br>
    Spam score: <b>${report.score}/100</b> ${report.score < 30 ? '✅' : '⚠️'}<br>
    Sample to: <b>${sampleData.email}</b> (${sampleData.company || 'no company'})
  </div>
  <a href="${approveUrl}" style="display:inline-block;background:#10b981;color:#fff;text-decoration:none;padding:14px 28px;border-radius:10px;font-weight:800;font-size:15px;">
    ✅ YES, SEND TO ALL ${campaign.totalCount} RECIPIENTS
  </a>
  <div style="font-size:11px;color:#64748b;margin-top:12px;">
    Ya <a href="${approveUrl}?action=reject" style="color:#dc2626;">❌ Cancel this campaign</a>
  </div>
  <div style="font-size:11px;color:#94a3b8;margin-top:10px;">
    ⚠️ Jab tak aap YES nahi dabayenge, koi email nahi jayegi.
  </div>
</div>`;

    // Inject banner at top of body
    if (/<body[^>]*>/i.test(sampleHtml)) {
      sampleHtml = sampleHtml.replace(/(<body[^>]*>)/i, `$1${approvalBanner}`);
    } else {
      sampleHtml = approvalBanner + sampleHtml;
    }

    // Send approval email
    const access = sender.accessToken ? decrypt(sender.accessToken) : '';
    const refresh = decrypt(sender.refreshToken);
    const c = oauthClient();
    c.setCredentials({ access_token: access, refresh_token: refresh });
    const gmail = google.gmail({ version: 'v1', auth: c });

    const raw = buildMime({
      from: `${sender.displayName ?? 'Startup Team'} <${sender.email}>`,
      to: approvalEmail,
      subject: `[APPROVAL NEEDED] ${finalSubject}`,
      html: sampleHtml,
      text: htmlToText(sampleHtml),
    });

    const res = await gmail.users.messages.send({
      userId: 'me',
      requestBody: { raw: Buffer.from(raw).toString('base64url') },
    });

    // Update campaign with approval info
    await prisma.campaign.update({
      where: { id: params.id },
      data: {
        approvalRequired: true,
        approvalStatus: 'TEST_SENT',
        approvalEmail,
        approvalToken: token,
        testSentAt: new Date(),
        status: 'AWAITING_APPROVAL',
        spamScore: report.score,
        spamIssues: report.issues as any,
      },
    });

    return NextResponse.json({
      ok: true,
      message: `Test email sent to ${approvalEmail}`,
      messageId: res.data.id,
      approvalEmail,
      spamScore: report.score,
      token,
      approveUrl,
    });
  } catch (err: any) {
    console.error('[request-approval]', err);
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
