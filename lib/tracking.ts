/**
 * Auto-inject tracking into email HTML:
 *  - 1x1 transparent tracking pixel (open tracking)
 *  - Wrap all links with click tracking
 */

export function injectTracking(
  html: string,
  recipientId: string,
  appUrl: string
): string {
  if (!recipientId || !appUrl) return html;

  const token = Buffer.from(recipientId).toString('base64url');
  const pixelUrl = `${appUrl}/api/track/open/${token}`;

  // 1. Add tracking pixel before </body> (or at end)
  const pixelHtml = `<img src="${pixelUrl}" width="1" height="1" alt="" style="display:block;width:1px;height:1px;border:0;outline:none;text-decoration:none;opacity:0" />`;

  let output = html;

  // Insert pixel before closing body
  if (/<\/body>/i.test(output)) {
    output = output.replace(/<\/body>/i, `${pixelHtml}</body>`);
  } else {
    output = output + pixelHtml;
  }

  // 2. Wrap links with click tracking
  output = output.replace(
    /<a\s+([^>]*?)href=["']([^"']+)["']([^>]*?)>/gi,
    (match, before, href, after) => {
      // Skip mailto, tel, unsubscribe, tracking pixel, and anchors
      if (
        href.startsWith('mailto:') ||
        href.startsWith('tel:') ||
        href.startsWith('#') ||
        href.includes('/api/track/') ||
        href.includes('/api/unsubscribe/') ||
        href.includes('javascript:')
      ) {
        return match;
      }
      const wrapped = `${appUrl}/api/track/click/${token}?url=${encodeURIComponent(href)}`;
      return `<a ${before}href="${wrapped}"${after}>`;
    }
  );

  return output;
}
