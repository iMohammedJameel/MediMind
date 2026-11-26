// src/modules/scheduler/internal.route.js
const express = require('express');
const router = express.Router();
const schedulerService = require('./scheduler.service');

/**
 * Internal endpoint called by the BullMQ worker (MEDICATION_SCHEDULER queue).
 * Generates today's DoseEvents for all active medications.
 * Not part of the public API — must stay unreachable from the ALB in production.
 */
router.post('/medications/sync', async (req, res) => {
  try {
    const result = await schedulerService.generateDailyDoses();
    res.status(200).json({ success: true, data: result });
  } catch (error) {
    res.status(500).json({ success: false, error: { code: 'SYNC_FAILED', message: error.message } });
  }
});

router.get('/scheduler/status', async (req, res) => {
  try {
    const result = await schedulerService.processOverdueDoses();
    res.status(200).json({ success: true, data: result });
  } catch (error) {
    res.status(500).json({ success: false, error: { code: 'SWEEP_FAILED', message: error.message } });
  }
});

module.exports = router;
