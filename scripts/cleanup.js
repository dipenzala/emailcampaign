require('dotenv').config();
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

(async () => {
  console.log('═══════════════════════════════════════════');
  console.log(' 📊 BEFORE CLEANUP');
  console.log('═══════════════════════════════════════════\n');

  // Current state
  const campaigns = await prisma.campaign.findMany({
    orderBy: { createdAt: 'desc' },
    take: 10,
  });

  console.log('Campaigns:');
  for (const c of campaigns) {
    const [sent, total, queued] = await Promise.all([
      prisma.campaignRecipient.count({ where: { campaignId: c.id, status: 'SENT' } }),
      prisma.campaignRecipient.count({ where: { campaignId: c.id } }),
      prisma.campaignRecipient.count({ where: { campaignId: c.id, status: 'QUEUED' } }),
    ]);
    console.log(`  [${c.status}] ${c.name.slice(0, 35)}`);
    console.log(`       Stored: sent=${c.sentCount} total=${c.totalCount}`);
    console.log(`       Actual: sent=${sent} total=${total} queued=${queued}`);
  }

  const senders = await prisma.senderAccount.findMany();
  const sendersUsed = senders.filter(s => s.sentToday > 0);
  console.log('\nSenders:');
  console.log(`  Total: ${senders.length}`);
  console.log(`  Connected: ${senders.filter(s => s.status === 'CONNECTED').length}`);
  console.log(`  Used today: ${sendersUsed.length} (avg ${sendersUsed.length ? Math.round(sendersUsed.reduce((a,b)=>a+b.sentToday,0)/sendersUsed.length) : 0} each)`);
  console.log(`  Total sent today: ${senders.reduce((a,b)=>a+b.sentToday,0)}`);

  console.log('\n═══════════════════════════════════════════');
  console.log(' 🧹 CLEANUP STARTING...');
  console.log('═══════════════════════════════════════════\n');

  // 1. STOP all RUNNING campaigns
  const stopped = await prisma.campaign.updateMany({
    where: { status: 'RUNNING' },
    data: { status: 'STOPPED', completedAt: new Date() },
  });
  console.log(`✅ Stopped ${stopped.count} RUNNING campaigns`);

  // 2. Reset PROCESSING → QUEUED
  const resetProcessing = await prisma.campaignRecipient.updateMany({
    where: { status: 'PROCESSING' },
    data: { status: 'QUEUED', errorMessage: null },
  });
  console.log(`✅ Reset ${resetProcessing.count} PROCESSING → QUEUED`);

  // 3. Fix counters for ALL campaigns
  const allCampaigns = await prisma.campaign.findMany();
  for (const c of allCampaigns) {
    const [sent, total] = await Promise.all([
      prisma.campaignRecipient.count({ where: { campaignId: c.id, status: 'SENT' } }),
      prisma.campaignRecipient.count({ where: { campaignId: c.id } }),
    ]);
    if (c.sentCount !== sent || c.totalCount !== total) {
      await prisma.campaign.update({
        where: { id: c.id },
        data: { sentCount: sent, totalCount: total },
      });
    }
  }
  console.log(`✅ Recalculated counters for ${allCampaigns.length} campaigns`);

  // 4. Reset sender counters? NO — preserve daily usage
  console.log(`ℹ️  Sender daily counters preserved (${senders.reduce((a,b)=>a+b.sentToday,0)} sent today)`);

  // 5. Ensure worker flags are ON
  try {
    await prisma.$executeRawUnsafe(`
      CREATE TABLE IF NOT EXISTS worker_settings (
        key TEXT PRIMARY KEY, value TEXT NOT NULL, updated_at TIMESTAMP DEFAULT NOW()
      )
    `);
    await prisma.$executeRawUnsafe(`
      INSERT INTO worker_settings (key, value) VALUES ('worker_enabled', 'true')
      ON CONFLICT (key) DO UPDATE SET value = 'true'
    `);
    await prisma.$executeRawUnsafe(`
      INSERT INTO worker_settings (key, value) VALUES ('bulk_worker_enabled', 'true')
      ON CONFLICT (key) DO UPDATE SET value = 'true'
    `);
    console.log(`✅ Worker flags enabled`);
  } catch (e) {
    console.log(`⚠️  Worker flags failed: ${e.message}`);
  }

  // 6. Check warm-up status — disable for existing senders
  const warmupSenders = senders.filter(s => s.warmupEnabled);
  if (warmupSenders.length > 0) {
    await prisma.senderAccount.updateMany({
      where: { warmupEnabled: true },
      data: { warmupEnabled: false, dailyLimit: 350 },
    });
    console.log(`✅ Disabled warm-up for ${warmupSenders.length} senders`);
  }

  console.log('\n═══════════════════════════════════════════');
  console.log(' ✅ CLEANUP DONE');
  console.log('═══════════════════════════════════════════\n');

  const finalQueued = await prisma.campaignRecipient.count({ where: { status: 'QUEUED' } });
  console.log(`📬 Queued emails ready: ${finalQueued}`);
  console.log(`👥 Connected senders: ${senders.filter(s => s.status === 'CONNECTED').length}`);
  console.log(`🔋 Total sender capacity left: ${senders.reduce((a,b)=>a+(350-b.sentToday),0)}`);

  await prisma.$disconnect();
})().catch(e => { console.error('❌', e.message); process.exit(1); });
