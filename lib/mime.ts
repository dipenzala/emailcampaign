export function buildMime(opts:{from:string;to:string;subject:string;html:string;text:string;unsubscribeUrl?:string}) {
  const boundary = '=_b_' + Math.random().toString(36).slice(2);
  const headers = [
    `From: ${opts.from}`,
    `To: ${opts.to}`,
    `Subject: =?UTF-8?B?${Buffer.from(opts.subject).toString('base64')}?=`,
    'MIME-Version: 1.0',
    `Content-Type: multipart/alternative; boundary="${boundary}"`,
  ];
  if (opts.unsubscribeUrl) {
    headers.push(`List-Unsubscribe: <${opts.unsubscribeUrl}>`);
    headers.push('List-Unsubscribe-Post: List-Unsubscribe=One-Click');
  }
  const body =
`--${boundary}
Content-Type: text/plain; charset="UTF-8"
Content-Transfer-Encoding: base64

${Buffer.from(opts.text).toString('base64')}

--${boundary}
Content-Type: text/html; charset="UTF-8"
Content-Transfer-Encoding: base64

${Buffer.from(opts.html).toString('base64')}

--${boundary}--`;
  return headers.join('\r\n') + '\r\n\r\n' + body;
}
export function htmlToText(html: string) {
  return html.replace(/<style[\s\S]*?<\/style>/gi,'')
    .replace(/<script[\s\S]*?<\/script>/gi,'')
    .replace(/<br\s*\/?>/gi,'\n')
    .replace(/<\/p>/gi,'\n\n')
    .replace(/<[^>]+>/g,'')
    .replace(/\n{3,}/g,'\n\n')
    .trim();
}
