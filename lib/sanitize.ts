import sanitizeHtml from 'sanitize-html';
export function sanitizeForPreview(html: string) {
  return sanitizeHtml(html, {
    allowedTags: sanitizeHtml.defaults.allowedTags.concat(['html','head','body','style','meta','img','table','thead','tbody','tr','td','th']),
    allowedAttributes: { '*': ['style','class','id','href','src','alt','width','height','title','target','colspan','rowspan'] },
    allowedSchemes: ['http','https','mailto','cid','data'],
    disallowedTagsMode: 'discard',
    allowVulnerableTags: false,
  });
}
export function validateHtml(html: string): { ok: boolean; error?: string } {
  if (!html || html.trim().length < 20) return { ok:false, error:'HTML is empty or too short' };
  if (!/<html[\s>]/i.test(html) && !/<body[\s>]/i.test(html)) return { ok:false, error:'Missing <html> or <body> tag' };
  if (/<script[\s>]/i.test(html)) return { ok:false, error:'<script> tags are not allowed' };
  return { ok:true };
}
