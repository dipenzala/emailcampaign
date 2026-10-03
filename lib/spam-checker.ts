const SPAMMY_WORDS = ['free','act now','limited time','click here','buy now','order now','cash','prize','winner','congratulations','urgent','guarantee','no risk','special promotion','make money','earn extra','work from home','cheap','discount','lowest price','risk-free','satisfaction guaranteed','dear friend','unsecured','credit','debt','viagra','casino','lottery','weight loss','as seen on'];
const SUBJECT_PATTERNS = [
  { re: /[A-Z]{5,}/, msg: 'Subject has 5+ consecutive uppercase letters', pts: 8 },
  { re: /!{2,}/, msg: 'Multiple exclamation marks', pts: 6 },
  { re: /\${2,}/, msg: 'Multiple dollar signs', pts: 10 },
  { re: /\b(free|winner|prize|urgent)\b/i, msg: 'Spammy keyword in subject', pts: 15 },
  { re: /^\s*$/, msg: 'Empty subject', pts: 20 },
];
const DISPOSABLE = new Set(['tempmail.com','guerrillamail.com','mailinator.com','10minutemail.com','throwaway.email','trashmail.com','yopmail.com','sharklasers.com','temp-mail.org','getnada.com','fakeinbox.com','maildrop.cc']);
const ROLES = new Set(['admin','info','support','sales','contact','help','noreply','no-reply','postmaster','webmaster','abuse','billing','marketing','office','hello','team']);

export type SpamIssue = { severity: 'low'|'medium'|'high'; category: string; message: string; points: number };
export type SpamReport = { score: number; issues: SpamIssue[]; ok: boolean; warning: boolean; blocked: boolean };

export function checkEmail(opts: { subject: string; html: string; fromEmail: string }): SpamReport {
  const issues: SpamIssue[] = [];
  let score = 0;
  const add = (severity: SpamIssue['severity'], category: string, message: string, points: number) => {
    issues.push({ severity, category, message, points });
    score += points;
  };

  if (!opts.subject || !opts.subject.trim()) add('high','subject','Subject empty',20);
  for (const { re, msg, pts } of SUBJECT_PATTERNS) if (re.test(opts.subject)) add('medium','subject',msg,pts);

  const html = opts.html || '';
  if (!/unsubscribe/i.test(html)) add('high','compliance','No unsubscribe link',25);
  const imgCount = (html.match(/<img[\s>]/gi) || []).length;
  const textLength = html.replace(/<[^>]+>/g, '').trim().length;
  if (imgCount > 0 && textLength < 100) add('medium','content','Mostly images',15);
  if (imgCount > 5) add('low','content','Too many images',5);
  const links = (html.match(/href=["']([^"']+)["']/gi) || []).length;
  if (links > 20) add('medium','content','Too many links',10);
  const shorteners = ['bit.ly','goo.gl','tinyurl.com','t.co','ow.ly'];
  if (shorteners.some(s => html.toLowerCase().includes(s))) add('high','content','URL shortener detected',20);
  const plainText = html.replace(/<[^>]+>/g, ' ');
  const letters = plainText.match(/[A-Za-z]/g) || [];
  const caps = plainText.match(/[A-Z]/g) || [];
  if (letters.length > 20 && caps.length / letters.length > 0.4) add('medium','content','Over 40% uppercase',10);
  const lower = plainText.toLowerCase();
  const found: string[] = [];
  for (const w of SPAMMY_WORDS) if (lower.includes(w)) found.push(w);
  if (found.length > 0) add('medium','content',`Spammy words: ${found.slice(0,5).join(', ')}`,Math.min(20,found.length*3));
  if (/<script[\s>]/i.test(html)) add('high','html','Contains <script> tag',30);
  if (/\son\w+\s*=/i.test(html)) add('medium','html','Inline event handlers',10);
  if (/https?:\/\/(localhost|127\.0\.0\.1|0\.0\.0\.0)/i.test(html)) add('high','html','Localhost links',25);

  const finalScore = Math.min(100, score);
  return { score: finalScore, issues, ok: finalScore < 30, warning: finalScore >= 30 && finalScore < 50, blocked: finalScore >= 50 };
}

export function checkEmailHygiene(email: string) {
  const [local, domain] = email.toLowerCase().split('@');
  const isRole = ROLES.has(local);
  const isDisp = DISPOSABLE.has(domain);
  let s = 100;
  if (isRole) s -= 20;
  if (isDisp) s -= 60;
  return { isRoleAccount: isRole, isDisposable: isDisp, score: Math.max(0, s) };
}
