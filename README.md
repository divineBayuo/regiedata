<div align="center">

# Regie Data

**Smart attendance management for churches, schools, and organizations.**

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Firestore-FFCA28?logo=firebase)](https://firebase.google.com)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart)](https://dart.dev)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Web-lightgrey)](https://flutter.dev)

[Features](#features) · [Screenshots](#screenshots) · [Getting Started](#getting-started) · [Architecture](#architecture) · [Deployment](#deployment) · [Contributing](#contributing)

</div>

---

## Overview

Regie Data is a cross-platform Flutter application that replaces paper-based and spreadsheet attendance systems with a live, cloud-synced solution. Admins create attendance sessions in seconds, generate QR codes and PINs, and get real-time analytics on member participation, finances, and engagement. Members check in by scanning a QR code or entering a PIN — no login complexity required on their end.

Built for the Ghana market with GHS pricing, MoMo-aware billing, and Paystack payment integration.

---

## Features

### For Members
- **QR Code Check-in** — scan the session QR code with the in-app scanner
- **PIN Check-in** — enter the 6-digit session PIN manually
- **Attendance History** — view a personal record of every session attended
- **Real-time Notifications** — receive alerts when a session starts, when promoted to admin, or when role changes occur
- **Profile Management** — manage personal details, occupation, family, and department

### For Admins
- **Live Session Management** — create sessions with auto-generated QR codes and PINs, share via clipboard or system share sheet
- **Active Session Monitoring** — live attendee count, money tracking, and PIN display
- **Session History** — full record of all past sessions with attendance counts
- **Member Management** — add, edit, filter, promote, approve, and remove members across four tabs (All, Pending Admins, Admins, Analytics)
- **Member Analytics** — demographic pie charts for gender, age groups, departments, families, and occupation
- **Financial Tracking** — record money collected per session, monthly bar charts, all-time totals
- **Attendance Analytics** — weekly, monthly, and yearly bar charts with period switching

### Advanced Analytics (Pro / Business)
1. **Attendance Rate per Member** — percentage progress bars per member with green/amber/red thresholds
2. **Session Performance** — horizontal bar chart ranking event names by total attendance
3. **Day-of-Week Heatmap** — colour-coded bar chart showing which days have highest turnout
4. **Attendance Rate Over Time** — percentage of total members attending per session across last 20 sessions
5. **Member Attendance Streaks** — current and best consecutive session streaks with flame indicators
6. **Financial Per-Session Breakdown** — collected amount, attendee count, and per-head value per session

### Subscription Plans

| Feature | Free | Pro | Business |
|---|---|---|---|
| Organizations | 1 | Up to 5 | Unlimited |
| Members per org | 30 | Unlimited | Unlimited |
| Attendance history | 30 days | Full | Full |
| Basic analytics | ✅ | ✅ | ✅ |
| Advanced analytics | ❌ | ✅ | ✅ |
| Financial breakdown | ❌ | ✅ | ✅ |
| CSV export | ❌ | ✅ | ✅ |
| Team management | ❌ | ❌ | ✅ |
| Custom branding | ❌ | ❌ | ✅ |
| API access | ❌ | ❌ | ✅ |
| Price | $0 | $4.99/mo | $9.99/mo |

Payments processed via [Paystack](https://paystack.com) with recurring monthly billing.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter 3.x (Dart 3.x) |
| Backend / Database | Firebase Firestore |
| Authentication | Firebase Auth (Email + Google Sign-In) |
| File Storage | Firebase Storage |
| Crash Reporting | Firebase Crashlytics |
| Payments | Paystack Subscriptions API |
| QR Scanning | `mobile_scanner` |
| QR Generation | `qr_flutter` |
| Notifications | Firestore-based in-app feed |
| State Management | `setState` + Firestore streams |
| Platform | Android, iOS, Web |

---

## Project Structure

```
lib/
├── helper_functions/
│   ├── organization_context.dart   # SharedPreferences active org lookup
│   └── role_navigation.dart        # Post-login routing by role
│
├── models/
│   ├── organization_model.dart
│   └── plan_limits.dart            # Single source of truth for plan caps
│
├── screens/
│   ├── admin_dashboard.dart        # Overview + Analytics tabs
│   ├── advanced_analytics_screen.dart
│   ├── all_attendance_screen.dart
│   ├── attendance_history_screen.dart
│   ├── code_entry_screen.dart
│   ├── manage_users_screen.dart
│   ├── notification_screen.dart
│   ├── org_customization_screen.dart
│   ├── organization_selector_screen.dart
│   ├── pending_admin_screen.dart
│   ├── qr_scanner_screen.dart
│   ├── signinpage.dart
│   ├── signuppage.dart
│   ├── splashscreen.dart
│   ├── subscription_screen.dart
│   ├── team_management_screen.dart
│   ├── user_home_screen.dart
│   └── user_profile_screen.dart
│
├── services/
│   ├── notification_service.dart        # Firestore notification writer
│   ├── organization_service.dart        # Org CRUD + membership logic
│   ├── paystack_webview_mobile.dart     # WebViewController checkout (Android/iOS)
│   ├── paystack_webview_web.dart        # HtmlElementView checkout (Web)
│   └── subscription_service.dart       # Plan management + Paystack entry point
│
└── widgets/
    ├── main_shell.dart             # Bottom navigation shell (IndexedStack)
    ├── plan_gate.dart              # Feature lock overlay + upgrade dialog
    └── plan_limit_banner.dart      # Inline amber limit warning
```

---

## Getting Started

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) 3.x or higher
- [Firebase CLI](https://firebase.google.com/docs/cli) installed and authenticated
- A [Paystack](https://paystack.com) account with subscription plans created
- Android Studio or VS Code with Flutter/Dart extensions

### Installation

**1. Clone the repository**
```bash
git clone https://github.com/divineBayuo/regiedata.git
cd regiedata
```

**2. Install dependencies**
```bash
flutter pub get
```

**3. Set up Firebase**

- Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
- Enable **Firestore**, **Authentication** (Email/Password + Google), and **Storage**
- Run FlutterFire CLI to generate `firebase_options.dart`:
```bash
dart pub global activate flutterfire_cli
flutterfire configure
```
- Download `google-services.json` → place at `android/app/google-services.json`
- Download `GoogleService-Info.plist` → place at `ios/Runner/GoogleService-Info.plist`

**4. Configure environment**

Create a `.env` file in the project root:
```env
PAYSTACK_PUBLIC_KEY=pk_test_your_key_here
PAYSTACK_SECRET_KEY=sk_test_your_key_here
```

> ⚠️ The `.env` file is gitignored. Never commit secret keys to the repository.

**5. Set up Paystack subscription plans**

In your Paystack dashboard → Products → Subscriptions → Plans:
- Create a **Pro** plan: GHS 4.99/month, interval: monthly
- Create a **Business** plan: GHS 9.99/month, interval: monthly

Copy the plan codes (e.g. `PLN_abc123`) into `lib/services/subscription_service.dart`:
```dart
const _planCodes = {
  'pro': 'PLN_YOUR_PRO_PLAN_CODE',
  'business': 'PLN_YOUR_BUSINESS_PLAN_CODE',
};
```

**6. Deploy the Firebase Cloud Function (webhook handler)**
```bash
cd functions
npm install
firebase deploy --only functions
```

Copy the deployed function URL and add it as a webhook endpoint in your Paystack dashboard → Settings → API Keys & Webhooks.

**7. Run the app**
```bash
# Android
flutter run

# iOS (requires macOS + Xcode)
flutter run -d ios

# Web
flutter run -d chrome
```

---

## Firestore Security Rules

Apply these rules in your Firebase Console → Firestore → Rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    function isSignedIn() { return request.auth != null; }

    match /users/{userId} {
      allow read: if isSignedIn();
      allow write: if isSignedIn() && request.auth.uid == userId;
    }

    match /organizations/{orgId} {
      allow read: if isSignedIn();
      allow create: if isSignedIn();
      allow update, delete: if isSignedIn();
    }

    match /organization_members/{membershipId} {
      allow read: if isSignedIn();
      allow create: if isSignedIn();
      allow update, delete: if isSignedIn();
    }

    match /attendance_sessions/{sessionId} {
      allow read: if isSignedIn();
      allow create, update, delete: if isSignedIn();
    }

    match /attendance/{attendanceId} {
      allow read, write: if isSignedIn();
    }

    match /notifications/{userId}/items/{item} {
      allow read: if request.auth != null && request.auth.uid == userId;
      allow write: if request.auth != null;
    }

    match /subscription_cancellations/{docId} {
      allow create: if isSignedIn();
      allow read, update: if false; // Cloud Function only
    }
  }
}
```

---

## Architecture

### Navigation

```
App Start
  └── SplashScreen (checks auth state)
        ├── Not authenticated → SignInPage / SignUpPage
        └── Authenticated → OrganizationSelectorScreen
                                └── (org selected) → MainShell
                                      ├── Tab 0: HomeWidget (role-aware)
                                      │     ├── AdminDashboard    (role: admin, approved)
                                      │     ├── PendingAdminScreen (role: admin, pending)
                                      │     └── UserHomeScreen    (role: user)
                                      ├── Tab 1: OrganizationSelectorScreen
                                      ├── Tab 2: NotificationsScreen (with unread badge)
                                      └── Tab 3: UserProfileScreen
```

### Role System

Every user is assigned a role per organization, stored in `organization_members`:

| Role | `isApproved` | Access |
|---|---|---|
| `user` | `true` | Check in, view own attendance |
| `admin` | `false` | Pending — sees PendingAdminScreen |
| `admin` | `true` | Full admin dashboard and management |

### Notification Flow

```
Admin creates session
  └── NotificationService.notifySessionStarted()
        └── Writes to notifications/{userId}/items  ← for every member except creator
              └── NotificationsScreen StreamBuilder reacts in real time
```

Role change events (promote, approve, demote, remove) follow the same pattern, each writing to the affected user's notification feed.

### Subscription Flow (Paystack Subscriptions API)

```
User taps Upgrade
  └── SubscriptionService.subscribe()
        └── showPaystackCheckout() [platform-conditional]
              ├── Mobile → WebViewController + Paystack inline JS
              └── Web    → HtmlElementView iframe + postMessage
                    └── User pays first month
                          └── Paystack creates recurring subscription
                                └── Paystack fires charge.success webhook
                                      └── Cloud Function verifies signature
                                            └── Updates users/{uid}.plan in Firestore
                                                  └── planStream() emits new plan
                                                        └── PlanGate unlocks features
```

On subsequent months, Paystack auto-charges and fires webhooks automatically. If payment fails, the Cloud Function handles `invoice.payment_failed` and downgrades the plan after the configured grace period.

---

## Plan Gating

Features are gated using the `PlanGate` widget, which streams the user's plan from Firestore in real time:

```dart
// Wrap any feature that requires a paid plan:
PlanGate(
  requiredPlan: 'pro',
  feature: 'CSV Export',
  child: ElevatedButton(
    onPressed: exportCsv,
    child: const Text('Export CSV'),
  ),
)
```

Hard limits (org count, member count) are enforced at the point of creation using `PlanLimits`:

```dart
final plan = await SubscriptionService.getUserPlan(uid);
if (_organizations.length >= PlanLimits.maxOrganizations(plan)) {
  // show upgrade prompt
  return;
}
```

---

## Deployment

### Android (Play Store)

**1. Generate a release keystore** (one time — store it permanently):
```bash
keytool -genkey -v -keystore regie-release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias regie-key
```

**2. Create `android/key.properties`** (gitignored):
```
storePassword=your_password
keyPassword=your_key_password
keyAlias=regie-key
storeFile=/absolute/path/to/regie-release.jks
```

**3. Build the release AAB:**
```bash
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab
```

**4. Upload to Google Play Console → Internal Testing → promote to Production.**

### iOS (App Store)

iOS builds require macOS and Xcode. From a Windows machine, use [Codemagic](https://codemagic.io) CI/CD:

1. Connect the GitHub repository to Codemagic
2. Add signing certificates and provisioning profiles in Codemagic settings
3. Add App Store Connect API key for automated upload
4. Trigger a build — Codemagic handles the Mac environment

A `codemagic.yaml` is included in the repository root for CI configuration.

### Web

```bash
flutter build web --release
# Deploy the build/web directory to Firebase Hosting, Netlify, or Vercel
firebase deploy --only hosting
```

---

## Environment Variables

| Variable | Description | Required |
|---|---|---|
| `PAYSTACK_PUBLIC_KEY` | Paystack public key (safe in client) | ✅ |
| `PAYSTACK_SECRET_KEY` | Paystack secret key (**server only**) | ✅ Cloud Function |

The Flutter app loads these from `.env` via `flutter_dotenv`. The secret key must never appear in client code — it lives exclusively in Firebase Cloud Function environment config:
```bash
firebase functions:config:set paystack.secret_key="sk_live_xxx"
```

---

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Commit your changes: `git commit -m 'feat: add your feature'`
4. Push to the branch: `git push origin feature/your-feature`
5. Open a Pull Request

### Code Style

- Follow the existing dark-theme design system (`_bg`, `_surface`, `_green`, `_greenDark`)
- All new screens must be responsive — test at 360dp width minimum
- New paid features must be wrapped with `PlanGate`
- Notification triggers must include a try-catch and surface errors via snackbar

---

## Roadmap

- [ ] Paystack recurring subscription webhook handler (Cloud Function)
- [ ] Push notifications via FCM (currently Firestore-based in-app only)
- [ ] Offline mode with local SQLite cache
- [ ] Bulk member import via CSV upload
- [ ] Export to PDF attendance reports
- [ ] Multi-language support (English + Twi)
- [ ] Dark / light theme toggle

---

## License

This project is licensed under the MIT License — see [LICENSE](LICENSE) for details.

---

## Contact

**Divine Bayuo** — [@divineBayuo](https://github.com/divineBayuo)

Project Link: [https://github.com/divineBayuo/regiedata](https://github.com/divineBayuo/regiedata)

---

<div align="center">
Built with ❤️ for Ghana and beyond.
</div>