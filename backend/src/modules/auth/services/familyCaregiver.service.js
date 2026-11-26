const Account = require("../models/Account.model");
const FamilyCaregiver = require("../models/FamilyCaregiver.model");
const bcrypt = require("bcrypt");
const {
  generateAccessToken,
  generateRefreshToken,
  verifyToken,
} = require("../../../shared/utils/jwt.util");
const { logger } = require("../../../shared/utils/logger");
const AppError = require("../../../shared/utils/AppError");
const mongoose = require("mongoose");
const {
  _verifyUniqueness,
  _finalizeSession,
} = require("../utils/auth.utils");
const ServiceResponse = require("../../../shared/utils/ServiceResponse");

class FamilyCaregiverService {

  async registerEmail(userData) {
    const { credentials, phone, nationalNumber, role } = userData;
    let account;
    let profile;

    await _verifyUniqueness({ email: credentials.email, phone });

    try {
      account = new Account({
        email: credentials.email,
        ...(phone ? { phone } : {}),
        ...(nationalNumber ? { nationalNumber } : {}),
        passwordHash: credentials.password,
        role: role || "FAMILY_CAREGIVER",
        isActive: true,
        sessions: [],
      });
      await account.save();

      profile = this._createProfileInstance(FamilyCaregiver, account._id, userData);
      await profile.save();
    } catch (err) {
      if (account?._id && !profile) {
        await Account.deleteOne({ _id: account._id }).catch(() => {});
      }
      throw err;
    }

    const sessionData = await _finalizeSession(account, profile);

    return new ServiceResponse({
      status: "SUCCESS",
      en: "Registration completed successfully.",
      ar: "تمت عملية التسجيل بنجاح.",
      data: sessionData,
    });
  }
  
  async registerPhone(userData) {
    const { credentials, email, nationalNumber, role } = userData;
    let account;
    let profile;

    await _verifyUniqueness({ phone: credentials.phone, email });

    try {
      account = new Account({
        phone: credentials.phone,
        ...(email ? { email } : {}),
        ...(nationalNumber ? { nationalNumber } : {}),
        passwordHash: credentials.password,
        role: role || "FAMILY_CAREGIVER",
        isActive: true,
        sessions: [],
      });
      await account.save();

      profile = this._createProfileInstance(FamilyCaregiver, account._id, userData);
      await profile.save();
    } catch (err) {
      if (account?._id && !profile) {
        await Account.deleteOne({ _id: account._id }).catch(() => {});
      }
      throw err;
    }

    const sessionData = await _finalizeSession(account, profile);

    return new ServiceResponse({
      status: "SUCCESS",
      en: "Registration completed successfully.",
      ar: "تمت عملية التسجيل بنجاح.",
      data: sessionData,
    });
  }

  _createProfileInstance(Model, accountId, userData) {
    const {
      firstName,
      lastName,
      dateOfBirth,
      gender,
      bloodType,
      height,
      weight,
      profilePictureUrl,
      address,
      emergencyContact,
      allergies,
      whatsappOptIn,
      preferredLanguage,
      consents,
      relation,
      subscription,
      alertSettings,
      ...extraFields
    } = userData;

    return new Model({
      accountId,
      firstName,
      lastName,
      dateOfBirth,
      gender,
      bloodType,
      height,
      weight,
      profilePictureUrl,
      address,
      emergencyContact,
      allergies,
      whatsappOptIn,
      preferredLanguage,
      consents,
      subscription: subscription || { plan: "free" },
      alertSettings: alertSettings || {
        instantMissed: true,
        weeklyReport: true,
        monthlyReport: false,
      },
      ...extraFields,
    });
  }
}

module.exports = new FamilyCaregiverService();
