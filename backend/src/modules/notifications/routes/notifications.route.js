const express = require('express');
const notificationsController = require('../controllers/notifications.controller');
const { authenticate } = require('../../../shared/middleware/auth.middleware');

const router = express.Router();

router.use(authenticate);

router.get('/', notificationsController.list);
router.get('/unread-count', notificationsController.getUnreadCount);
router.patch('/:id/read', notificationsController.markAsRead);
router.patch('/read-all', notificationsController.markAllAsRead);

// FCM device token registration (Flutter / web push clients)
router.post('/device-token', async (req, res, next) => {
  try {
    const DeviceToken = require('../models/DeviceToken.model');
    const { token, platform = 'ANDROID' } = req.body;
    if (!token) {
      return res.status(400).json({
        success: false,
        error: { code: 'VALIDATION_ERROR', message: 'token is required' }
      });
    }
    await DeviceToken.findOneAndUpdate(
      { token },
      { accountId: req.accountId, token, platform, lastActiveAt: new Date() },
      { upsert: true, new: true }
    );
    res.status(200).json({ success: true, data: { status: 'REGISTERED' } });
  } catch (error) {
    next(error);
  }
});

module.exports = router;
