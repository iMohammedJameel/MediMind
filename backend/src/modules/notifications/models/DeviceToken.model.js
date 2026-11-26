// src/modules/notifications/models/DeviceToken.model.js
const mongoose = require('mongoose');

const DeviceTokenSchema = new mongoose.Schema(
  {
    accountId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Account',
      required: true,
      index: true
    },
    token: {
      type: String,
      required: true,
      trim: true
    },
    platform: {
      type: String,
      enum: ['ANDROID', 'IOS', 'WEB'],
      default: 'ANDROID'
    },
    lastActiveAt: {
      type: Date,
      default: Date.now
    }
  },
  { timestamps: true }
);

// One row per token; refresh lastActiveAt on re-registration
DeviceTokenSchema.index({ token: 1 }, { unique: true });
DeviceTokenSchema.index({ accountId: 1, platform: 1 });

module.exports = mongoose.model('DeviceToken', DeviceTokenSchema);
