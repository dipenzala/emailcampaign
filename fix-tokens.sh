#!/usr/bin/env bash

echo "==============================================="
echo " 🧪 Test Sender (Real Email Bhejo)"
echo "==============================================="

cd "$(dirname "$0")" 2>/dev/null || true

set -a
source .env
set +a

# Test email address — apna email daalo
TEST_TO="dipen.zala1@gmail.com"

node -e "
const { PrismaClient } = require('@prisma/client');
const { google } = require('googleapis');
const crypto = require('crypto');

const KEY = Buffer.from(process.env.TOKEN_ENCRYPTION_KEY || '', 'hex');

function decrypt(payload) {
  const buf = Buffer.from(payload, 'base64');
  const iv = buf.subarray(0, 12);
  const tag = buf.subarray(12, 28);
  const data = buf.subarray(28);
  const d = crypto.createDecipheriv('aes-256-gcm', KEY, iv);
  d.setAuthTag(tag);
  return Buffer.concat([d.update(data), d.final()]).toString('utf8');
}

(async () => {
  const p = new PrismaClient();
  const s = await p.senderAccount.findFirst({ where: { status: 'CONNECTED' } });
  if (!s) { console.log('❌ No sender'); return; }

  const access = s.accessToken ? decrypt(s.accessToken) : '';
  const refresh = decrypt(s.refreshToken);
  
  const c = new google.auth.OAuth2(
    process.env.GOOGLE_CLIENT_ID,
    process.env.GOOGLE_CLIENT_SECRET,
    process.env.GOOGLE_REDIRECT_URI
  );
  c.setCredentials({ access_token: access, refresh_token: refresh });
  const gmail = google.gmail({ version: 'v1', auth: c });

  const boundary = '=_b_' + Math.random().toString(36).slice(2);
  const raw = [
    'From: ' + s.email,
    'To: $TEST_TO',
    'Subject: =?UTF-8?B?' + Buffer.from('Test from EmailCampaign').toString('base64') + '?=',
    'MIME-Version: 1.0',
    'Content-Type: multipart/alternative; boundary=\"' + boundary + '\"',
    '',
    '--' + boundary,
    'Content-Type: text/plain; charset=\"UTF-8\"',
    '',
    'Test email. If you received this, sender works!',
    '',
    '--' + boundary,
    'Content-Type: text/html; charset=\"UTF-8\"',
    '',
    '<h1>✅ Sender Working!</h1><p>From: ' + s.email + '</p>',
    '',
    '--' + boundary + '--',
  ].join('\r\n');

  try {
    const res = await gmail.users.messages.send({
      userId: 'me',
      requestBody: { raw: Buffer.from(raw).toString('base64url') },
    });
    console.log('✅ EMAIL SENT to $TEST_TO');
    console.log('   Message ID: ' + res.data.id);
    console.log('   From: ' + s.email);
  } catch (err) {
    console.log('❌ FAILED: ' + err.message);
    if (/insufficient|permission/i.test(err.message)) {
      console.log('   → Scope issue — reconnect sender');
    }
  }
  
  await p.\$disconnect();
})();
"