import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'models/user_model.dart';
import 'screens/dashboard_page.dart';
import 'screens/gate_screens.dart';
import 'screens/landing_page.dart';
import 'screens/login_page.dart';
import 'screens/signup_page.dart';
import 'services/audit_service.dart';
import 'services/audit_log_service.dart';
import 'services/auth_service.dart';
import 'services/church_rules_service.dart';
import 'services/connectivity_service.dart';
import 'services/gallery_service.dart';
import 'services/landing_content_service.dart';
import 'services/localization_service.dart';
import 'services/notification_service.dart';
import 'services/permission_service.dart';
import 'services/remote_config_service.dart';
import 'services/role_registry_service.dart';
import 'services/module_config_service.dart';
import 'services/software_control_service.dart';
import 'theme/app_theme.dart';
import 'widgets/branded_loader.dart';
import 'widgets/offline_banner.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Date symbols for every locale, so a date can be formatted in the reader's
  // language rather than the device's. Bundled with `intl` — no network, and
  // without it DateFormat only knows en_US. See formatLandingDate().
  await initializeDateFormatting();

  try {
    // Uses platform options derived from google-services.json (Android) and
    // GoogleService-Info.plist (iOS); on web uses firebase_options.dart.
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);

    // Offline cache, stated explicitly rather than left to the library default.
    //
    // cloud_firestore already enables disk persistence on Android/iOS, but caps
    // it at 40 MB and evicts silently — so whether a screen works offline
    // depended on how much else had been read since. Unlimited makes the
    // behaviour predictable. On web, persistence is OFF by default and this is
    // what turns it on.
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );

    if (!kIsWeb) {
      // FCM background handling is mobile-only.
      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);
    }
    // Initialize notifications (no-ops on web).
    await NotificationService.initialize();
  } catch (e) {
    if (kDebugMode) print('Firebase initialization failed: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => PermissionService()),
        ChangeNotifierProvider(create: (_) => RoleRegistryService()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => RemoteConfigService()),
        ChangeNotifierProvider(create: (_) => ModuleConfigService()),
        ChangeNotifierProvider(create: (_) => SoftwareControlService()),
        ChangeNotifierProvider(create: (_) => LocalizationService()),
        ChangeNotifierProvider(create: (_) => LandingContentService()),
        ChangeNotifierProvider(create: (_) => GalleryService()),
        ChangeNotifierProvider(create: (_) => ConnectivityService()),
        ChangeNotifierProvider(create: (_) => ChurchRulesService()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'Ahaw Mobile',
          navigatorKey: NotificationService.navigatorKey,
          debugShowCheckedModeBanner: false,
          themeMode: themeProvider.themeMode,
          theme: themeProvider.lightTheme,
          darkTheme: themeProvider.darkTheme,
          builder: (context, child) => OfflineBanner(
            child: child ?? const SizedBox.shrink(),
          ),
          routes: {
            '/': (context) => const AuthWrapper(),
            '/login': (context) => const LoginPage(),
            '/signup': (context) => const SignupPage(),
            '/dashboard': (context) => const DashboardPage(),
          },
        );
      },
    );
  }
}

/// Listens to auth state and loads permissions when a user signs in.
/// Mirrors the web's AuthProvider + PermissionProvider combination.
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  String? _lastLoadedUid;
  UserModel? _lastUserModel;
  bool _statusHookAttached = false;

  /// Turns a live `users/{uid}.status` transition into a device notification.
  ///
  /// This is the free half of "tell the member their request was decided": the
  /// app is already watching its own user document, so when an approver acts in
  /// the web the client raises the notification itself. No Cloud Function, no
  /// Blaze plan. It only fires while the app is alive — see
  /// NotificationService.showLocal for why that limit is unavoidable here.
  void _attachStatusHook(AuthService auth, LocalizationService loc) {
    if (_statusHookAttached) return;
    _statusHookAttached = true;
    auth.onStatusChanged = (previous, next) {
      if (previous != 'pending') return;
      if (next == 'active') {
        NotificationService.showLocal(
          id: 90001,
          title: loc.t('pages.approvedNotificationTitle'),
          body: loc.t('pages.approvedNotificationBody'),
        );
      } else if (next == 'rejected') {
        NotificationService.showLocal(
          id: 90002,
          title: loc.t('pages.rejectedNotificationTitle'),
          body: loc.t('pages.rejectedGeneric'),
        );
      }
    };
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final permissionService =
        Provider.of<PermissionService>(context, listen: false);
    final remoteConfig = Provider.of<RemoteConfigService>(context);

    _attachStatusHook(
        authService, Provider.of<LocalizationService>(context, listen: false));

    // Remote gates controlled from the web admin (Mobile App Control)
    if (remoteConfig.killSwitch) {
      return MaintenanceScreen(message: remoteConfig.maintenanceMessage);
    }
    if (remoteConfig.forceUpdate) {
      return ForceUpdateScreen(
        latestVersionName: remoteConfig.latestVersionName,
        updateUrl: remoteConfig.updateUrl,
      );
    }

    // When a user signs in, load their permissions immediately
    if (authService.isAuthenticated &&
        authService.userModel != null &&
        authService.userModel!.id != _lastLoadedUid) {
      _lastLoadedUid = authService.userModel!.id;
      // Call synchronously in postFrameCallback — applies defaults instantly,
      // then fetches Firestore overrides in background
      WidgetsBinding.instance.addPostFrameCallback((_) {
        permissionService.loadForUser(
          userId: authService.userModel!.id,
          hierarchyLevel: authService.userModel!.hierarchyLevel,
          role: authService.userModel!.role,
        );
        // Report this device/session for the web audit dashboard
        AuditService.report(authService.userModel!);
        // Record the login in the shared audit trail
        AuditLogService.log(
          user: authService.userModel!,
          action: 'login',
          targetType: 'auth',
          description:
              '${authService.userModel!.fullNameEnglish ?? authService.userModel!.username} signed in',
        );
      });
      _lastUserModel = authService.userModel;
    }

    // When a user signs out, clear permissions and log the logout
    if (!authService.isAuthenticated && _lastLoadedUid != null) {
      _lastLoadedUid = null;
      final loggingOut = _lastUserModel;
      _lastUserModel = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        permissionService.clear();
        if (loggingOut != null) {
          AuditLogService.log(
            user: loggingOut,
            action: 'logout',
            targetType: 'auth',
            description: 'Signed out',
          );
        }
      });
    }

    // Show the welcome screen while Firebase auth state is being determined.
    if (authService.isLoading) {
      return const Scaffold(body: BrandedLoader());
    }

    // Authenticated but not yet an active member. Data access is denied
    // server-side in every one of these states, so each gets its own screen
    // rather than a dashboard whose every query fails.
    if (authService.isAuthenticated) {
      final status = authService.userModel?.status;

      if (status == 'pending') {
        return PendingApprovalScreen(
          parishName: authService.userModel?.atbiyaName,
          onSignOut: () => authService.signOut(),
        );
      }

      // Previously fell through to the dashboard, which looked like breakage
      // rather than a decision.
      if (status == 'rejected') {
        return RejectedScreen(
          reason: authService.userModel?.rejectedReason,
          onSignOut: () => authService.signOut(),
        );
      }

      // 'suspended', or an Auth account with no users/{uid} document at all.
      if (status == 'suspended' || status == 'missing') {
        return RejectedScreen(
          reason: null,
          onSignOut: () => authService.signOut(),
        );
      }
    }

    // Authenticated → Dashboard
    if (authService.isAuthenticated) {
      return const DashboardPage();
    }

    // Not authenticated → Landing
    return const LandingPage();
  }
}
