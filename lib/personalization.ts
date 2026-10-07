/**
 * Personalization + Subject formatting
 * Priority: name → company → email prefix
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

function nameFromEmail(email: string): string {
  if (!email) return 'Friend';
  const local = email.split('@')[0] || '';
  const clean = local.replace(/[._\-0-9]+/g, ' ').trim();
  const pretty = clean
    .split(/\s+/)
    .filter(Boolean)
    .map(w => w.charAt(0).toUpperCase() + w.slice(1).toLowerCase())
    .join(' ');
  return pretty || 'Friend';
}

/**
 * Get best display label.
 * Priority: name → company → email prefix
 */
export function getRecipientName(data: Record<string, any>): string {
  const personName = String(data.name || '').trim();
  if (personName) return personName;

  const company = String(data.company || '').trim();
  if (company) return company;

  return nameFromEmail(String(data.email || ''));
}

/**
 * Format subject with client name (or company) + CONGRATULATIONS prefix.
 */
export function formatSubject(subjectTemplate: string, data: Record<string, any>): string {
  if (!subjectTemplate) return '';
  const name = getRecipientName(data);
  const subject = subjectTemplate.trim();

  // If has {{name}} or {{company}} variable — just render
  if (/\{\{\s*(name|company)/.test(subject)) {
    return renderTemplate(subject, { ...data, name, company: data.company || name });
  }

  // If starts with CONGRATULATIONS
  const upperSubject = subject.toUpperCase();
  if (upperSubject.startsWith('CONGRATULATIONS')) {
    const rest = subject.replace(/^congratulations[\s🎉🎊!.,]*/i, '').trim();
    return rest
      ? `CONGRATULATIONS 🎉 ${name} — ${rest}`
      : `CONGRATULATIONS 🎉 ${name}`;
  }

  // Prepend prefix
  return `CONGRATULATIONS 🎉 ${name} — ${subject}`;
}

export function personalize(data: Record<string, any>, subjectTemplate: string, htmlTemplate: string) {
  return {
    subject: formatSubject(subjectTemplate, data),
    html: renderTemplate(htmlTemplate, data),
  };
}
