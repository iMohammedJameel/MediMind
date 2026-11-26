<div align="center">

# 💊 MediMind — Smart Medication Care Platform
### منصة MediMind للرعاية الدوائية الذكية ومتابعة الالتزام بالعلاج

[![Flutter](https://img.shields.io/badge/Flutter-Android%20%7C%20Web-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Node.js](https://img.shields.io/badge/Node.js-Express%205-339933?logo=nodedotjs&logoColor=white)](https://nodejs.org)
[![MongoDB](https://img.shields.io/badge/MongoDB-Mongoose-47A248?logo=mongodb&logoColor=white)](https://www.mongodb.com)
[![Redis](https://img.shields.io/badge/Redis-BullMQ-DC382D?logo=redis&logoColor=white)](https://redis.io)
[![Bilingual](https://img.shields.io/badge/Localization-Arabic%20RTL%20%2B%20English%20LTR-0F766E)](#screens-gallery--معرض-الشاشات-باللغتين)

**Arabic-first (RTL) & English (LTR) mobile health companion engineered for patients and caregivers — combining precision dose alarms, prescription OCR scanning, drug-interaction alerts, offline-first resilience, and live caregiver monitoring.**

**منظومة متكاملة للمريض ومقدم الرعاية (أفراد العائلة والمختصين) تضم تطبيق هاتف مبني بـ Flutter وواجهة برمجية Backend بـ Node.js/Express 5 مع دعم كامل للغة العربية (RTL) والإنجليزية (LTR)، منبّه جرعات دقيق، قراءة الروشتات (OCR)، وتنبيهات التداخلات الدوائية.**

</div>

---

## 📑 Table of Contents | المحتويات
- [Overview | نظرة عامة](#overview--نظرة-عامة)
- [Architecture & Tech Stack | البنية التقنية](#architecture--tech-stack--البنية-التقنية)
- [Key Features | أبرز المزايا](#key-features--أبرز-المزايا)
- [Project Structure | هيكل المشروع](#project-structure--هيكل-المشروع)
- [Quick Start | التشغيل السريع](#quick-start--التشغيل-السريع)
  - [1. Backend API (`backend/`)](#1-backend-api-backend)
  - [2. Flutter Mobile App (`mobile/`)](#2-flutter-mobile-app-mobile)
- [API Modules Overview | وحدات الـ API](#api-modules-overview--وحدات-الـ-api)
- [Screens Gallery (AR & EN) | معرض الشاشات باللغتين](#screens-gallery--معرض-الشاشات-باللغتين)

---

## Overview | نظرة عامة

| English | العربية |
|---|---|
| **MediMind** helps elderly and chronic-care patients stay on top of complex medication schedules while keeping family caregivers informed in real time. The mobile client handles unreliable networks seamlessly via offline dose caching and queued action sync, rings reliably on Android 14+ with full-screen dose alarms and snooze recovery, and presents clear bilingual typography (`Cairo`) with adjustable accessibility scaling. | يهدف **MediMind** إلى مساعدة المرضى وكبار السن على الالتزام بمواعيد الأدوية بدقة، مع إتاحة متابعة لحظية لأفراد العائلة ومقدمي الرعاية. يعمل التطبيق بسلاسة حتى مع انقطاع الإنترنت عبر التخزين المحلي ومزامنة الجرعات تلقائياً عند عودة الاتصال، ويدعم منبّه شاشة كاملة وإمكانية الغفوة وقراءة الروشتات بالكاميرا مع واجهة مريحة لكبار السن وخط `Cairo`. |

---

## Architecture & Tech Stack | البنية التقنية

| Layer | Technologies |
|---|---|
| **Mobile App (`mobile/`)** | Flutter (`Dart >=3.4`), `flutter_bloc` (Cubit), `go_router`, `dio` + `dio_cookie_manager`, `flutter_secure_storage`, `local_auth` (Biometrics), `flutter_local_notifications` (`AlarmClock` + inexact fallback + foreground `DoseAlarmWatchdog`), `just_audio` + `audio_session`, `fl_chart`, `image_picker`, `connectivity_plus`, `share_plus` + `pdf` |
| **Backend API (`backend/`)** | Node.js, Express 5 (`CommonJS`), Mongoose (MongoDB), Redis + BullMQ scheduler, `node-cron` fallback, JWT access/refresh split-token auth + `cookie-parser`, Zod validation, `bcrypt`, `express-rate-limit`, Firebase Admin (FCM), AWS SDK (SES/SNS/S3 optional), Jest + Supertest |
| **Security & Hardening** | HttpOnly refresh cookies + `flutter_secure_storage` access token, biometric app gate, AES-256 PHI field encryption hooks, automated session-expiry handling (`401`), strict Play-ready Android permissions (`SCHEDULE_EXACT_ALARM` opt-in + safe fallback), no committed secrets or signing keys |

---

## Key Features | أبرز المزايا

- **Patient Today Dashboard (`TodayScreen`)**: Daily progress ring & summary, Next Dose spotlight, As-Needed (PRN) one-tap logging, grouped Morning/Afternoon/Evening schedule, Taken / Snooze / Skip confirmation sheets, and offline-banner sync state.
- **Full-Screen Dose Alarm & Watchdog (`AlarmScreen`)**: Custom `alarm_tone` audio channel (`AudioAttributesUsage.alarm`), haptic vibration loop, 5 / 15 / 30 min snooze options, Android 14 `SCHEDULE_EXACT_ALARM` permission helper, `inexactAllowWhileIdle` fallback, and in-app `DoseAlarmWatchdog` so due doses always open & ring even while browsing the app.
- **Medications & Refill Management (`MedicationsScreen`)**: Two-step medication wizard with custom slot times, meal relation badges, search & filters (`All`, `Active`, `Low stock`, `Chronic`), drug-interaction alerts, low-stock badges, and pharmacy refill requests.
- **Prescription OCR Scan (`ScanScreen`)**: Camera/gallery capture with guided framing tips and review-before-save flow.
- **Adherence Analytics (`AdherenceScreen`)**: Daily/Weekly/Monthly views, streak tracking, 7-day heatmap log, `fl_chart` trend visualization, and shareable PDF adherence reports.
- **Care Circle & Caregiver Portal (`CareCircleScreen`, `CaregiverPatientsScreen`, `PatientDetailScreen`)**: Patient-caregiver invitation codes/links, missed-dose alerts (`NotificationsScreen`), remote schedule inspection, confirm-on-behalf, and one-tap call/emergency dialing.
- **Accessibility & Bilingual UI (`SettingsScreen`)**: Instant **Arabic (RTL)** / **English (LTR)** switching, Arabic-Indic vs Western digits toggle, 12h/24h clock format, elderly base font scaling + slider (`1.0x–1.4x`), Light/Dark/System themes, and Biometric lock.

---

## Project Structure | هيكل المشروع

```text
MediMind/
├── backend/                     # Node.js + Express 5 REST API & scheduler
│   ├── src/
│   │   ├── config/              # Env validation, DB/Redis configs
│   │   ├── modules/             # auth, profiles, medications, doses, relationships,
│   │   │                        # notifications, conditions, notes, payments, content,
│   │   │                        # uploads, scheduler
│   │   └── shared/              # Middleware, rate limiters, loggers, crypto utilities
│   ├── Dockerfile
│   ├── .env.example
│   ├── index.js
│   └── package.json
│
├── mobile/                      # Flutter Mobile Application (Android / Web)
│   ├── lib/
│   │   ├── l10n/                # Symmetric AR & EN translation catalog (AppStrings)
│   │   ├── models/              # Immutable domain models
│   │   ├── modules/             # Screen modules + Cubits (17 feature modules)
│   │   ├── services/            # Auth, Doses, Meds, Alarms, Watchdog, OfflineSync, Biometrics
│   │   └── shared/              # Theme, Glass UI components, Dio client, CacheHelper
│   ├── android/                 # Android configuration, alarm channel resources, signing guide
│   ├── assets/                  # App icon, logo, Cairo font, alarm_tone.wav
│   └── test/                    # Unit, Cubit, Watchdog, Layout Regression & Visual Audit tests
│
├── docs/screenshots/            # Arabic & English UI showcase PNGs
│   ├── ar/
│   └── en/
├── .gitignore
└── README.md
```

---

## Quick Start | التشغيل السريع

### 1. Backend API (`backend/`)

```bash
cd backend
npm install
cp .env.example .env      # Configure MONGO_URI, REDIS_URL, JWT secrets & encryption key
npm run seed              # Optional: seed initial data
npm run dev               # Starts Express API on http://localhost:8080
```

Run backend tests:
```bash
npm test
```

### 2. Flutter Mobile App (`mobile/`)

```bash
cd mobile
flutter pub get

# Android Emulator -> host localhost:8080
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080/api/v1

# Physical Android device via USB (recommended)
adb reverse tcp:8080 tcp:8080
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8080/api/v1
```

Run static analysis & full automated test suite:
```bash
flutter analyze --no-fatal-infos
flutter test -r compact
```

> Release builds disable cleartext HTTP and require HTTPS (`--dart-define=API_BASE_URL=https://api.example.com/api/v1`) and release keystore setup as documented in [`mobile/android/README_SIGNING.md`](mobile/android/README_SIGNING.md).

---

## API Modules Overview | وحدات الـ API

All routes are served under `/api/v1`:

| Prefix | Purpose |
|---|---|
| `/health` | Service health probe |
| `/auth` | Registration, email/phone login, refresh token rotation, password reset, logout |
| `/profiles` | Patient/caregiver profile, emergency contact, timezone sync, pharmacy directory |
| `/medications` | Medication CRUD, OCR prescription scan (`/scan`), drug-interaction warnings, refills |
| `/doses` | Daily/range dose schedules, dose confirm/skip, extra (PRN) logging |
| `/relationships` | Care circle invites, acceptance/decline, caregiver revocations |
| `/notifications` | Unread badge count, notification feed, mark-read, FCM token registration |
| `/conditions`, `/notes`, `/payments`, `/content` | Health conditions, clinical notes, billing, and educational content |
| `/internal` | BullMQ worker / cron dose-generation synchronization hooks |

---

## Screens Gallery | معرض الشاشات باللغتين

### Onboarding & Authentication | الترحيب والتسجيل

| Screen / الشاشة | العربية (Arabic RTL) | English (LTR) |
|:---:|:---:|:---:|
| **Splash**<br>شاشة البداية | <img src="docs/screenshots/ar/01_splash.png" width="230" alt="Splash AR"/> | <img src="docs/screenshots/en/01_splash.png" width="230" alt="Splash EN"/> |
| **Onboarding**<br>الجولة التعريفية | <img src="docs/screenshots/ar/02_onboarding.png" width="230" alt="Onboarding AR"/> | <img src="docs/screenshots/en/02_onboarding.png" width="230" alt="Onboarding EN"/> |
| **Login**<br>تسجيل الدخول | <img src="docs/screenshots/ar/03_login.png" width="230" alt="Login AR"/> | <img src="docs/screenshots/en/03_login.png" width="230" alt="Login EN"/> |
| **Register**<br>إنشاء حساب | <img src="docs/screenshots/ar/04_register.png" width="230" alt="Register AR"/> | <img src="docs/screenshots/en/04_register.png" width="230" alt="Register EN"/> |
| **Forgot Password**<br>استعادة كلمة المرور | <img src="docs/screenshots/ar/05_forgot_password.png" width="230" alt="Forgot Password AR"/> | <img src="docs/screenshots/en/05_forgot_password.png" width="230" alt="Forgot Password EN"/> |
| **Reset Password**<br>تعيين كلمة مرور جديدة | <img src="docs/screenshots/ar/06_reset_password.png" width="230" alt="Reset Password AR"/> | <img src="docs/screenshots/en/06_reset_password.png" width="230" alt="Reset Password EN"/> |
| **Profile Setup**<br>إعداد الملف الصحي | <img src="docs/screenshots/ar/07_profile_setup.png" width="230" alt="Profile Setup AR"/> | <img src="docs/screenshots/en/07_profile_setup.png" width="230" alt="Profile Setup EN"/> |

### Patient Experience | تجربة المريض

| Screen / الشاشة | العربية (Arabic RTL) | English (LTR) |
|:---:|:---:|:---:|
| **Today Schedule**<br>جدول اليوم والجرعات | <img src="docs/screenshots/ar/08_today.png" width="230" alt="Today AR"/> | <img src="docs/screenshots/en/08_today.png" width="230" alt="Today EN"/> |
| **Medications**<br>قائمة الأدوية والمخزون | <img src="docs/screenshots/ar/09_medications.png" width="230" alt="Medications AR"/> | <img src="docs/screenshots/en/09_medications.png" width="230" alt="Medications EN"/> |
| **Add Medication (2-Step)**<br>إضافة دواء بخطوتين | <img src="docs/screenshots/ar/10_medications_add.png" width="230" alt="Add Medication AR"/> | <img src="docs/screenshots/en/10_medications_add.png" width="230" alt="Add Medication EN"/> |
| **OCR Prescription Scan**<br>مسح الروشتة بالكاميرا | <img src="docs/screenshots/ar/11_scan.png" width="230" alt="Scan AR"/> | <img src="docs/screenshots/en/11_scan.png" width="230" alt="Scan EN"/> |
| **Adherence Tracker**<br>تقرير وسجل الالتزام | <img src="docs/screenshots/ar/12_adherence.png" width="230" alt="Adherence AR"/> | <img src="docs/screenshots/en/12_adherence.png" width="230" alt="Adherence EN"/> |
| **Care Circle**<br>دائرة الرعاية والدعوات | <img src="docs/screenshots/ar/13_care_circle.png" width="230" alt="Care Circle AR"/> | <img src="docs/screenshots/en/13_care_circle.png" width="230" alt="Care Circle EN"/> |
| **Notifications Feed**<br>مركز الإشعارات | <img src="docs/screenshots/ar/14_notifications.png" width="230" alt="Notifications AR"/> | <img src="docs/screenshots/en/14_notifications.png" width="230" alt="Notifications EN"/> |
| **Dose Alarm**<br>شاشة منبّه الجرعة الكاملة | <img src="docs/screenshots/ar/15_alarm.png" width="230" alt="Alarm AR"/> | <img src="docs/screenshots/en/15_alarm.png" width="230" alt="Alarm EN"/> |
| **Settings & Accessibility**<br>الإعدادات وإمكانية الوصول | <img src="docs/screenshots/ar/16_settings.png" width="230" alt="Settings AR"/> | <img src="docs/screenshots/en/16_settings.png" width="230" alt="Settings EN"/> |
| **Privacy Policy**<br>سياسة الخصوصية | <img src="docs/screenshots/ar/17_privacy_policy.png" width="230" alt="Privacy Policy AR"/> | <img src="docs/screenshots/en/17_privacy_policy.png" width="230" alt="Privacy Policy EN"/> |

### Caregiver Experience | تجربة مقدم الرعاية

| Screen / الشاشة | العربية (Arabic RTL) | English (LTR) |
|:---:|:---:|:---:|
| **My Patients**<br>قائمة المرضى المرتبطين | <img src="docs/screenshots/ar/18_caregiver_patients.png" width="230" alt="Caregiver Patients AR"/> | <img src="docs/screenshots/en/18_caregiver_patients.png" width="230" alt="Caregiver Patients EN"/> |
| **Patient Detail**<br>متابعة جدول المريض | <img src="docs/screenshots/ar/19_caregiver_patient_detail.png" width="230" alt="Patient Detail AR"/> | <img src="docs/screenshots/en/19_caregiver_patient_detail.png" width="230" alt="Patient Detail EN"/> |
