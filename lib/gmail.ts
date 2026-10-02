import { google } from 'googleapis';
export function oauthClient() {
  return new google.auth.OAuth2(
    process.env.GOOGLE_CLIENT_ID,
    process.env.GOOGLE_CLIENT_SECRET,
    process.env.GOOGLE_REDIRECT_URI,
  );
}
export function gmailFor(accessToken: string, refreshToken: string) {
  const c = oauthClient();
  c.setCredentials({ access_token: accessToken, refresh_token: refreshToken });
  return google.gmail({ version: 'v1', auth: c });
}
