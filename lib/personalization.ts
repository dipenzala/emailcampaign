// ═══════════════════════════════════════════
// PERSONALIZATION — clean & reliable
// ═══════════════════════════════════════════

/**
 * Replace {{variable}} in template.
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
 * Get display label from contact.
 * Priority: name → company → email prefix
 */
export function getDisplayLabel(contact: {
  name?: string | null;
  company?: string | null;
  email?: string | null;
}): string {
  const name = String(contact?.name || '').trim();
  if (name) return name;

  const company = String(contact?.company || '').trim();
  if (company) return company;

  const email = String(contact?.email || '').trim();
  if (!email) return 'Friend';

  const local = email.split('@')[0] || '';
  const clean = local.replace(/[._\-0-9]+/g, ' ').trim();
  if (!clean) return 'Friend';

  return clean
    .split(/\s+/)
    .filter(Boolean)
    .map(w => w.charAt(0).toUpperCase() + w.slice(1).toLowerCase())
    .join(' ');
}

/**
 * ⭐ Format subject with recipient label.
 *
 * Rules:
 *  1. Subject has {{name}} or {{company}} → render directly
 *  2. Subject starts with "CONGRATULATIONS" → prepend label
 *  3. Else → "CONGRATULATIONS 🎉 [Label] — original subject"
 */
export function formatSubject(
  subjectTemplate: string,
  contact: { name?: string | null; company?: string | null; email?: string | null }
): string {
  if (!subjectTemplate) return '';

  const label = getDisplayLabel(contact);
  const subject = subjectTemplate.trim();

  // Rule 1: Has variable
  if (/\{\{\s*(name|company)/i.test(subject)) {
    return renderTemplate(subject, {
      name: contact.name || label,
      company: contact.company || label,
      email: contact.email || '',
    });
  }

  // Rule 2: Already starts with CONGRATULATIONS
  if (/^congratulations/i.test(subject)) {
    const rest = subject
      .replace(/^congratulations[\s🎉🎊!.,]*/i, '')
      .trim();
    return rest
      ? `CONGRATULATIONS 🎉 ${label} — ${rest}`
      : `CONGRATULATIONS 🎉 ${label}`;
  }

  // Rule 3: Prepend prefix
  return `CONGRATULATIONS 🎉 ${label} — ${subject}`;
}

/**
 * Full personalization (subject + html).
 */
export function personalize(
  contact: { name?: string | null; company?: string | null; email?: string | null; city?: string | null; phone?: string | null },
  subjectTemplate: string,
  htmlTemplate: string
) {
  return {
    subject: formatSubject(subjectTemplate, contact),
    html: renderTemplate(htmlTemplate, {
      name: contact.name || '',
      email: contact.email || '',
      company: contact.company || '',
      city: contact.city || '',
      phone: contact.phone || '',
    }),
  };
}
