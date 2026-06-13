import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'models/user_model.dart';
import 'screens/dashboard_page.dart';
import 'screens/gate_screens.dart';
import 'screens/landing_page.dart';
import 'screens/login_page.dart';
import 'services/audit_service.dart';
import 'services/audit_log_service.dart';
import 'services/auth_service.dart';
import 'services/landing_content_service.dart';
import 'services/localization_service.dart';
import 'services/notification_service.dart';
import 'services/permission_service.dart';
import 'services/remote_config_service.dart';
import 'theme/app_colors.dart';
import 'theme/theme_provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    // Uses google-services.json (Android) or GoogleService-Info.plist (iOS)
    // automatically — no hardcoded keys needed.
    await Firebase.initializeApp();
    
    // Initialize notifications
    await NotificationService.initialize();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (e) {
    if (kDebugMode) print('Firebase initialization failed: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => PermissionService()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => RemoteConfigService()),
        ChangeNotifierProvider(create: (_) => LocalizationService()),
        ChangeNotifierProvider(create: (_) => LandingContentService()),
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
          debugShowCheckedModeBanner: false,
          themeMode: themeProvider.themeMode,
          theme: themeProvider.lightTheme,
          darkTheme: themeProvider.darkTheme,
          routes: {
            '/': (context) => const AuthWrapper(),
            '/login': (context) => const LoginPage(),
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

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final permissionService =
        Provider.of<PermissionService>(context, listen: false);
    final remoteConfig = Provider.of<RemoteConfigService>(context);

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

    // Show splash/loading while Firebase auth state is being determined
    if (authService.isLoading) {
      return Scaffold(
        backgroundColor: AppColors.lightBackground,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'AHAW',
                style: GoogleFonts.notoSansEthiopic(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Authenticated → Dashboard
    if (authService.isAuthenticated) {
      return const DashboardPage();
    }

    // Not authenticated → Landing
    return const LandingPage();
  }
}
