# Mahibere Ahaw — Mobile (mobile_ahaw)

The Flutter mobile client for **Mahibere Ahaw**, an Ethiopian Orthodox church
management system. It shares one Firebase backend (project `mahibere-ahaw`) with
the web app (`../mahibere-ahaw`) — same Auth, same Firestore — so data created on
one client appears on the other.

## Stack

- **Flutter / Dart** with **Provider** (ChangeNotifier services)
- **Firebase**: Auth, Cloud Firestore, Cloud Messaging (push)
- **Cloudinary** for image/file uploads (Firebase Storage is deny-by-default)
- `image_picker`, `file_picker`, `url_launcher`, `google_fonts` (Noto Sans Ethiopic)

## Features (parity with the web app)

- **Auth**: username-or-email sign-in, self-service **Signup** with a
  **Pending-approval** gate, password change.
- **Dashboard** with role-scoped stats.
- **Members** directory (scoped reads) with create (real Auth account), edit,
  suspend, photo upload.
- **Membership Requests** approval queue (approvers) — activates pending signups.
- **Finance**: transactions, budgets, reports, **member tithes, pledges,
  requisition vouchers**.
- **Announcements, Plans, Reports** (with comment thread), **Meetings**
  (location + RSVP), **Teachings** (create/edit), **Church Rules** (admin edit),
  **Documents** (folder/upload/delete), **Missionary** (applications + reports),
  **Volunteer**, **Strategic Plan**, **Partner**, **Hige Denb**.
- **News** feed + manager (Cloudinary covers, draft/publish).
- **Inventory** (assets) and **HR** (employees).
- **Organisation** registry (Synod → Zone → Atbiya → Mahderat) and **MyAtbiya**
  parish console.
- **Church Map** (congregation pins), **About**, **Suggestion box**,
  **Notifications** (with tap deep-linking).
- **Permission Control** and admin config consumed from the web
  (Software Control nav/element flags, Module Config field/option config,
  role registry scope). CMS editing stays on the web (operational-first).
- 4 languages (Amharic default, English, Afaan Oromoo, Tigrinya) via
  `LocalizationService`, with live admin overrides from `siteConfig/pageStrings`.
- Light/dark theme; remote kill-switch / force-update gates.

## Architecture

- `lib/services/*` — one service per domain, talking to Firestore (mirrors the
  web's `src/services/*` collection names and field shapes).
- `lib/screens/` + `lib/screens/dashboard_items/` — one screen per module,
  reached from `lib/widgets/main_drawer.dart` (permission + remote-flag gated).
- `lib/models/`, `lib/i18n/translations.dart`, `lib/theme/`.
- Permissions: `PermissionService` + `role_permissions.dart` (defaults) +
  `RoleRegistryService` (scope from `siteConfig/roles`). Directory reads are
  scoped (head-office/diocese see all; a parish sees only its own members).

## Getting started

```bash
flutter pub get
flutter run
```

Firebase config is loaded from `android/app/google-services.json` and
`ios/Runner/GoogleService-Info.plist` (project `mahibere-ahaw`) — no keys in
source. Cloudinary cloud name / upload preset come from
`siteConfig/integrations` (with shared defaults).

## Checks

```bash
flutter analyze
flutter test
```
