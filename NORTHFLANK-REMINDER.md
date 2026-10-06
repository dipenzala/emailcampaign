# 🎛️ Northflank Setup Reminder

Aapne pehle Northflank pe ye setup kiya tha — same settings rakho:

## Already Configured
- Service: emailcampaign
- Repo: dipenzala/emailcampaign
- Branch: main
- Build: npm install && npx prisma generate
- Start: npm run worker OR node local-sender.js
- Env vars: 9 variables (DATABASE_URL, REDIS_URL, etc.)

## Ab Kya Add Karna Hai

### 1. Worker Control Button Use Karne Ke Liye
Ye nahi chahiye koi Northflank change — button Vercel pe hi chalta hai.
Bas DB me `worker_settings` table banegi pehli baar.

### 2. Test Flow
1. Northflank worker already running hai
2. Vercel pe `/control` kholo
3. ON/OFF button dabao
4. 5-10 sec me worker respond karega

## Dashboard Access
- https://emailcampaign-ten.vercel.app/control → ON/OFF button
- https://emailcampaign-ten.vercel.app/bulk → Manual bulk sender
- https://emailcampaign-ten.vercel.app/dashboard/live → Live dashboard
