// src/modules/scheduler/cron.js — in-process cron fallback so dose lifecycle
// works even without the BullMQ worker running.
const cron = require('node-cron');
const schedulerService = require('./scheduler.service');
const { logger } = require('../../shared/utils/logger');

let dailyJob = null;
let sweepJob = null;

function startScheduler() {
  if (dailyJob || sweepJob) return;

  // 02:00 UTC daily — generate the day's dose events
  dailyJob = cron.schedule('0 2 * * *', async () => {
    try {
      await schedulerService.generateDailyDoses();
    } catch (err) {
      logger.error(err, 'Daily dose generation cron failed');
    }
  });

  // every 5 minutes — flip PENDING -> LATE -> MISSED + escalate
  sweepJob = cron.schedule('*/5 * * * *', async () => {
    try {
      await schedulerService.processOverdueDoses();
    } catch (err) {
      logger.error(err, 'Overdue dose sweep cron failed');
    }
  });

  logger.info('Dose scheduler started (daily 02:00 UTC + 5-min overdue sweep)');
}

function stopScheduler() {
  if (dailyJob) { dailyJob.stop(); dailyJob = null; }
  if (sweepJob) { sweepJob.stop(); sweepJob = null; }
}

module.exports = { startScheduler, stopScheduler };
