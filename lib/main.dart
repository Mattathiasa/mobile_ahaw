import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'screens/dashboard_page.dart';
import 'screens/landing_page.dart';
import 'screens/login_page.dart';
import 'services/auth_service.dart';
import 'theme/app_colors.dart';
import 'theme/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    if (kDebugMode) {
      print("Firebase initialization failed: $e");
      print(
        "Please ensure you have added the google-services.json file for Android or GoogleService-Info.plist for iOS.",
      );
    }
  }
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
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
          // Define routes for navigation
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

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    if (authService.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (authService.isAuthenticated) {
      return const DashboardPage();
    } else {
      return const LandingPage();
    }
  }
}
