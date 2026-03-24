# Business Pulse — Local Business Automation

A production-ready Flutter app for small businesses, freelancers, and agencies. A complete offline-first business management suite with CRM, invoicing, WhatsApp automation, PDF generation, and device-transfer backup — all data stored privately on-device.

---

## 📲 Download & Test

**Latest Android APK**: [Download Business Pulse v1.0.0](https://github.com/Kaushal2402/app-business-automation/releases/latest)

### 🛠️ Installation Instructions
1. Download the `.apk` file from the link above.
2. On your Android device, open the file.
3. If prompted, allow "Install from unknown sources" in your settings.
4. Open **Business Pulse** and start managing your business!

> **Note**: For iOS, please build from source using Xcode as Apple requires app signing for installation on real devices.

---

## 🚀 Features

### 🔒 Security & Onboarding
- **Custom Security PIN** — Create and confirm your own 4-digit PIN on first launch (blocks weak codes like `1234`, `0000`, repeating digits)
- **Change PIN** — Update your security code anytime from Settings → Security
- **Biometric Auth** — Optional Face ID / Touch ID in addition to PIN
- **New User Flow**: `Splash → Onboarding → Create PIN → Business Profile → Dashboard`
- **Returning User Flow**: `Splash → Enter PIN → Dashboard`

### 📊 Dashboard
- Revenue totals, pipeline status, and recent activity
- Personalized Executive Summary with your business logo and name
- Quick-action shortcuts to add leads and create invoices

### 👥 CRM — Lead Management
- Add, edit, and track leads with status pipeline (New → Contacted → Proposal → Won/Lost)
- Estimated deal values and internal notes
- Follow-up reminders via local notifications

### 💰 Professional Invoicing
- Create invoices with multiple line items, configurable tax rate, and discounts
- Status tracking: Draft → Sent → Paid → Overdue
- **Branded PDF export** — invoices generated with your business logo, name, and contact details

### 🤖 WhatsApp Automation
- Pre-filled message templates for lead greetings and payment reminders
- **Dynamic branding** — templates auto-inject your business name
- One-tap launch into WhatsApp with `url_launcher`

### 📈 Reports & Analytics
- Revenue charts (monthly breakdown) using `fl_chart`
- Business insights with your saved logo and name in the executive header

### ⚙️ Settings
- **Dark / Light / System** theme
- **Language**: English 🇬🇧, Spanish 🇪🇸, French 🇫🇷
- **Currency** and **Tax Rate** defaults for invoices
- **Business Profile**: Name, email, phone, address, tax number, logo
- **Export All Data** — backup to `.bizbackup` file for device transfer
- **Change Security PIN**

### ☁️ Data Backup & Restore
- **Export**: Saves all data (Business Profile, Leads, Invoices) as a `bizbackup_YYYY-MM-DD.bizbackup` file and opens the iOS/Android share sheet
- **Import**: On first setup, choose "Import Old Business" to restore from a `.bizbackup` file — all data restored, goes straight to Dashboard
- Designed for **device-to-device transfer** with zero data loss

---

## 💻 Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter (iOS & Android) |
| State Management | `flutter_bloc` (Cubit pattern) |
| Local Database | `isar` — blazing-fast offline NoSQL DB |
| Secure Storage | `flutter_secure_storage` (PIN storage) |
| PDF Generation | `pdf` + `printing` packages |
| Charts | `fl_chart` |
| Notifications | `flutter_local_notifications` |
| Backup & Share | `share_plus` + `file_picker` |
| Localization | `flutter_localizations` + ARB files |
| DI | `get_it` |
| Typography | `google_fonts` (Inter) |

---

## 🗂️ Project Structure

```
lib/
├── core/
│   ├── services/         # BackupService, WhatsAppService, NotificationService
│   ├── theme/            # AppColors, ThemeData
│   ├── utils/            # IsarService, LocalAuthService
│   └── widgets/          # Shared UI components (AppBottomSheet)
├── features/
│   ├── auth/             # Splash, Onboarding, PIN Login, Profile Setup
│   ├── dashboard/        # Dashboard, Reports, Settings (with SettingsCubit)
│   ├── crm/              # Leads list, Lead detail, Growth Engine
│   ├── invoicing/        # Invoice list, create, detail, PDF
│   └── whatsapp/         # WhatsApp automation templates
├── l10n/                 # app_en.arb, app_es.arb, app_fr.arb
└── main.dart
```

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK ≥ 3.10
- Xcode (iOS) or Android Studio (Android)

### Run
```bash
flutter pub get
flutter run
```

### Backup File Extension
The app uses `.bizbackup` files (JSON format). These can only be imported back into **Business Pulse**.

---

## 📄 License

MIT License — see [LICENSE](LICENSE) for details.
