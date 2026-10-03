import { google } from 'googleapis';
export function oauthClient() {
  const clientId = process.env.GOOGLE_CLIENT_ID;
  const clientSecret = process.env.GOOGLE_CLIENT_SECRET;
  const redirectUri = process.env.GOOGLE_REDIRECT_URI;
  if (!clientId || !clientSecret || !redirectUri) {
    throw new Error('Missing OAuth env vars');
  }
  return new google.auth.OAuth2(clientId, clientSecret, redirectUri);
}
export function gmailFor(accessToken: string, refreshToken: string) {
  const c = oauthClient();
  c.setCredentials({ access_token: accessToken, refresh_token: refreshToken });
  return google.gmail({ version: 'v1', auth: c });
}
