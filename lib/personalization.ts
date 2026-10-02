export function renderTemplate(html: string, data: Record<string, any>) {
  return html.replace(/\{\{\s*(\w+)(?:\s*\|\s*default:"([^"]*)")?\s*\}\}/g, (_m, key, def) => {
    const v = data[key];
    if (v === undefined || v === null || v === '') return def ?? '';
    return String(v);
  });
}
