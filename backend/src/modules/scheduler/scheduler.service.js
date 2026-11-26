// src/modules/scheduler/scheduler.service.js
const DoseEvent = require('../doses/models/DoseEvent.model');
const Medication = require('../medications/models/Medication.model');
const Notification = require('../notifications/models/Notification.model');
const Relationship = require('../relationships/models/Relationship.model');
const Patient = require('../auth/models/Patient.model');
const mongoose = require('mongoose');
const { sendPushToAccount } = require('../notifications/services/push.service');
const { logger } = require('../../shared/utils/logger');

// Grace windows (minutes) for dose status transitions
const LATE_THRESHOLD_MINUTES = 15;
const MISSED_THRESHOLD_MINUTES = 30;

class SchedulerService {
  /**
   * Generate today's DoseEvents for ALL active medications (all patients).
   * Called by the BullMQ worker via POST /internal/medications/sync and by the daily cron.
   */
  async generateDailyDoses(date = new Date()) {
    const startOfDay = new Date(date.getFullYear(), date.getMonth(), date.getDate(), 0, 0, 0, 0);
    const endOfDay = new Date(date.getFullYear(), date.getMonth(), date.getDate(), 23, 59, 59, 999);

    const activeMeds = await Medication.find({ isActive: true });
    let created = 0;

    for (const med of activeMeds) {
      if (med.expirationDate && med.expirationDate < startOfDay) continue;
      if (med.schedule?.startDate && med.schedule.startDate > endOfDay) continue;
      if (med.schedule?.endDate && med.schedule.endDate < startOfDay) continue;

      const timesList = (med.schedule.timesOfDay && med.schedule.timesOfDay.length > 0)
        ? med.schedule.timesOfDay
        : [med.schedule.firstDoseTime || '08:00'];

      for (const timeStr of timesList) {
        const [hours, minutes] = timeStr.split(':').map(Number);
        const scheduledFor = new Date(
          date.getFullYear(), date.getMonth(), date.getDate(), hours || 0, minutes || 0, 0, 0
        );

        const existing = await DoseEvent.findOne({ medicationId: med._id, scheduledFor });
        if (!existing) {
          await DoseEvent.create({
            medicationId: med._id,
            patientId: med.patientId,
            scheduledFor,
            status: 'PENDING',
            escalationState: 'NONE'
          });
          created++;
        }
      }
    }

    logger.info(`Daily dose generation complete: ${created} new events created`);
    return { created, totalMedications: activeMeds.length };
  }

  /**
   * Periodic sweep (every 5 min):
   * - PENDING past scheduledFor + 15min  -> LATE
   * - PENDING past scheduledFor + 30min  -> MISSED + caregiver escalation
   */
  async processOverdueDoses() {
    const now = new Date();

    const lateCutoff = new Date(now.getTime() - LATE_THRESHOLD_MINUTES * 60 * 1000);
    const missedCutoff = new Date(now.getTime() - MISSED_THRESHOLD_MINUTES * 60 * 1000);

    // PENDING -> LATE (within the 15-30 min grace window)
    const lateDoses = await DoseEvent.find({
      status: 'PENDING',
      scheduledFor: { $lt: lateCutoff, $gt: missedCutoff }
    }).populate('medicationId');

    for (const dose of lateDoses) {
      dose.status = 'LATE';
      await dose.save();
    }

    // PENDING -> MISSED (past the full grace window)
    const missedDoses = await DoseEvent.find({
      status: { $in: ['PENDING', 'LATE'] },
      scheduledFor: { $lt: missedCutoff }
    }).populate('medicationId');

    for (const dose of missedDoses) {
      dose.status = 'MISSED';
      if (dose.escalationState !== 'CAREGIVER_NOTIFIED') {
        await this.escalateMissedDose(dose);
      }
      await dose.save();
    }

    if (lateDoses.length || missedDoses.length) {
      logger.info(`Overdue sweep: ${lateDoses.length} LATE, ${missedDoses.length} MISSED`);
    }

    return { late: lateDoses.length, missed: missedDoses.length };
  }

  /**
   * Escalation: notify the patient's caregivers (and the patient) about a missed dose.
   */
  async escalateMissedDose(dose) {
    try {
      const medName = dose.medicationId?.name || 'medication';
      const scheduledFor = dose.scheduledFor;

      dose.escalationState = 'CAREGIVER_NOTIFIED';

      // Notify the patient
      const patient = await Patient.findById(dose.patientId);
      if (patient?.accountId) {
        await Notification.create({
          recipientId: patient.accountId,
          type: 'DOSE_MISSED',
          title: 'Missed dose',
          titleAr: 'جرعة فائتة',
          message: `You missed your ${medName} dose scheduled at ${scheduledFor.toISOString()}.`,
          messageAr: `لم تتناول جرعة ${medName} المجدولة في ${scheduledFor.toISOString()}.`,
          data: { doseEventId: dose._id, medicationId: dose.medicationId?._id }
        });
        await sendPushToAccount(patient.accountId, {
          title: 'جرعة فائتة / Missed dose',
          body: `${medName} — ${scheduledFor.toISOString()}`,
          data: { doseEventId: String(dose._id), type: 'DOSE_MISSED' }
        });
      }

      // Notify accepted caregivers
      const relationships = await Relationship.find({
        patientId: dose.patientId,
        status: 'ACCEPTED'
      });

      for (const rel of relationships) {
        const caregiverProfile = await mongoose.model(rel.caregiverType).findById(rel.caregiverId);
        if (!caregiverProfile?.accountId) continue;

        await Notification.create({
          recipientId: caregiverProfile.accountId,
          type: 'DOSE_MISSED',
          title: 'Patient missed a dose',
          titleAr: 'المريض فوّت جرعة',
          message: `Your patient missed the ${medName} dose scheduled at ${scheduledFor.toISOString()}.`,
          messageAr: `المريض لم يتناول جرعة ${medName} المجدولة في ${scheduledFor.toISOString()}.`,
          data: { doseEventId: dose._id, patientId: dose.patientId, medicationId: dose.medicationId?._id }
        });
        await sendPushToAccount(caregiverProfile.accountId, {
          title: 'المريض فوّت جرعة / Patient missed a dose',
          body: `${medName} — ${scheduledFor.toISOString()}`,
          data: { doseEventId: String(dose._id), patientId: String(dose.patientId), type: 'DOSE_MISSED' }
        });
      }
    } catch (err) {
      logger.error(err, 'Failed to escalate missed dose notification');
    }
  }
}

module.exports = new SchedulerService();
