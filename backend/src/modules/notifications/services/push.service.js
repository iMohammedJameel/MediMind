// src/modules/notifications/services/push.service.js
// Firebase Cloud Messaging delivery for Flutter (Android/iOS) and web push clients.
// FCM is only used when FCM_* credentials are configured — otherwise delivery is skipped (logged).
const DeviceToken = require('../models/DeviceToken.model');
const { FCM_PROJECT_ID, FCM_CLIENT_EMAIL, FCM_PRIVATE_KEY } = require('../../../config/env');
const { logger } = require('../../../shared/utils/logger');

let fcmApp = null;

function getFcmApp() {
  if (fcmApp) return fcmApp;
  if (!FCM_PROJECT_ID || !FCM_CLIENT_EMAIL || !FCM_PRIVATE_KEY) return null;

  const admin = require('firebase-admin');
  fcmApp = admin.initializeApp({
    credential: admin.credential.cert({
      projectId: FCM_PROJECT_ID,
      clientEmail: FCM_CLIENT_EMAIL,
      privateKey: FCM_PRIVATE_KEY.replace(/\\n/g, '\n')
    })
  }, 'medimind-fcm');
  return fcmApp;
}

/**
 * Send a push notification to every registered device of an account.
 * Never throws — push failures must not break dose confirmations / escalations.
 */
async function sendPushToAccount(accountId, { title, body, data = {} }) {
  try {
    const devices = await DeviceToken.find({ accountId });
    if (!devices.length) return { sent: 0, reason: 'NO_REGISTERED_DEVICES' };

    const app = getFcmApp();
    if (!app) {
      logger.debug(`FCM not configured — skipping push to account ${accountId} (${devices.length} devices)`);
      return { sent: 0, reason: 'FCM_NOT_CONFIGURED' };
    }

    const { getMessaging } = require('firebase-admin/messaging');
    const response = await getMessaging(app).sendEachForMulticast({
      tokens: devices.map(d => d.token),
      notification: { title, body },
      data: Object.fromEntries(Object.entries(data).map(([k, v]) => [k, String(v)]))
    });

    // Prune invalid tokens so they don't accumulate
    const invalidTokens = [];
    response.responses.forEach((resp, i) => {
      if (!resp.success) invalidTokens.push(devices[i].token);
    });
    if (invalidTokens.length) {
      await DeviceToken.deleteMany({ token: { $in: invalidTokens } });
    }

    return { sent: response.successCount };
  } catch (err) {
    logger.error(err, 'Push notification delivery failed');
    return { sent: 0, reason: 'PUSH_ERROR' };
  }
}

module.exports = { sendPushToAccount };
