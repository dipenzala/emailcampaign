/**
 * Personalization engine for email subject + HTML.
 * Subject format: "CONGRATULATIONS 🎉 [Company Name]"
 */

/**
 * Render template string with data.
 */
export function renderTemplate(template: string, data: Record<string, any>): string {
  if (!template) return '';
  return template.replace(
    /\{\{\s*(\w+)(?:\s*\|\s*default\s*:\s*"([^"]*)")?\s*\}\}/g,
    (_m, key, def) => {
      const v = data[key];
      if (v === undefined || v === null || v === '') return def ?? '';
      return String(v);
    }
  );
}

/**
 * Extract company from email domain.
 * Fallback if company field is empty.
 *
 * Examples:
 *   rahul@acmecorp.com       → "Acmecorp"
 *   priya@tech-startup.io    → "Tech Startup"
 *   amit@mycompany.co.in     → "Mycompany"
 */
function companyFromEmail(email: string): string {
  if (!email) return 'Friend';
  const domain = email.split('@')[1] || '';
  if (!domain) return 'Friend';

  // Remove common TLDs
  const parts = domain.split('.');
  const name = parts[0] || '';

  // Skip generic providers
  const generic = ['gmail', 'yahoo', 'hotmail', 'outlook', 'live', 'icloud', 'aol', 'protonmail', 'zoho', 'yandex'];
  if (generic.includes(name.toLowerCase())) {
    return 'Friend';
  }

  // Clean: remove hyphens, underscores; capitalize
  const clean = name.replace(/[._\-]+/g, ' ').trim();
  const pretty = clean
    .split(/\s+/)
    .filter(Boolean)
    .map(w => w.charAt(0).toUpperCase() + w.slice(1).toLowerCase())
    .join(' ');

  return pretty || 'Friend';
}

/**
 * ⭐ Get best display name — COMPANY first, then email fallback.
 */
export function getRecipientCompany(data: Record<string, any>): string {
  const company = String(data.company || '').trim();
  if (company) return company;
  return companyFromEmail(String(data.email || ''));
}

/**
 * ⭐ Format subject with COMPANY NAME + CONGRATULATIONS prefix.
 *
 * Rules:
 *  1. If subject already has {{company}} → render it
 *  2. If subject starts with "CONGRATULATIONS" → append company name only
 *  3. Else → prepend "CONGRATULATIONS 🎉 [Company] — " before original subject
 *
 * Examples:
 *   Template: "Congratulations", Company: "Acme Corp"
 *     → "CONGRATULATIONS 🎉 Acme Corp"
 *
 *   Template: "Big Sale Today", Company: "Startup IO"
 *     → "CONGRATULATIONS 🎉 Startup IO — Big Sale Today"
 */
export function formatSubject(subjectTemplate: string, data: Record<string, any>): string {
  if (!subjectTemplate) return '';
  const company = getRecipientCompany(data);
  const subject = subjectTemplate.trim();

  // Rule 1: If already has {{company}} → render
  if (/\{\{\s*company/.test(subject)) {
    return renderTemplate(subject, { ...data, company });
  }

  // Rule 2: Starts with CONGRATULATIONS
  const upperSubject = subject.toUpperCase();
  if (upperSubject.startsWith('CONGRATULATIONS')) {
    const rest = subject.replace(/^congratulations[\s🎉🎊!.,]*/i, '').trim();
    return rest
      ? `CONGRATULATIONS 🎉 ${company} — ${rest}`
      : `CONGRATULATIONS 🎉 ${company}`;
  }

  // Rule 3: Prepend
  return `CONGRATULATIONS 🎉 ${company} — ${subject}`;
}

/**
 * Full personalization helper.
 */
export function personalize(data: Record<string, any>, subjectTemplate: string, htmlTemplate: string) {
  return {
    subject: formatSubject(subjectTemplate, data),
    html: renderTemplate(htmlTemplate, data),
  };
}
