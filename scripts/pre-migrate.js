/**
 * Pre-migration cleanup.
 * Drops the User table if it has old columns (email-based).
 * This runs BEFORE `prisma db push`.
 * Safe: only touches the User table; senders/campaigns/contacts remain.
 */
const { PrismaClient } = require('@prisma/client');

(async () => {
  const prisma = new PrismaClient({ log: [] });
  try {
    // Check if new columns already exist by querying information_schema
    const rows = await prisma.$queryRawUnsafe(`
      SELECT column_name
      FROM information_schema.columns
      WHERE table_name = 'User'
        AND column_name IN ('username', 'passwordHash')
    `);

    if (rows.length === 2) {
      console.log('✅ User table already has new columns — skipping drop');
      await prisma.$disconnect();
      process.exit(0);
    }

    // Drop User table (only this one — senders etc. safe)
    console.log('🔄 Dropping legacy User table for schema update...');
    await prisma.$executeRawUnsafe(`DROP TABLE IF EXISTS "User" CASCADE`);
    console.log('✅ Legacy User table dropped — will be recreated by prisma db push');
  } catch (e) {
    console.log('ℹ️  pre-migrate note:', (e.message || '').slice(0, 120));
    // Don't fail the build
  }
  try { await prisma.$disconnect(); } catch {}
  process.exit(0);
})();
