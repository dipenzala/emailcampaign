# EmailCampaign

Full-stack email campaign dashboard — Next.js + Prisma + BullMQ + Gmail API (OAuth 2.0).

## Prerequisites
- Node.js 18+
- PostgreSQL 14+
- Redis 6+

## Setup

```bash
# 1. Create DB
createdb emailcampaign

# 2. Configure .env (Google OAuth credentials, DB, Redis)

# 3. Push schema
npm run db:push

# 4. Run (Next.js + worker together)
npm run dev
# Deployed Fri, Oct  2, 2026  9:30:28 PM
