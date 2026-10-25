import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

import 'firebase_options.dart';

import 'screens/opening_splash.dart';
import 'screens/login_page.dart';
import 'screens/register_page.dart';
import 'screens/splash_screen.dart';
import 'screens/resident/resident_home.dart';
import 'screens/resident/my_reports.dart';
import 'screens/resident/map_page.dart';
import 'screens/resident/profile.dart';
import 'screens/resident/admin_home.dart';
import 'screens/resident/report_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // App Check protects Firebase AI Logic (the chatbot) from abuse.
  // The debug provider is used so the app works when installed by hand
  // (capstone demo). Switch to Play Integrity before a Play Store release.
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug,
    appleProvider: AppleProvider.debug,
  );

  runApp(const CitiFixApp());
}

class CitiFixApp extends StatelessWidget {
  const CitiFixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CitiFix Manila',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
        ),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        // Opening splash: checks the saved login, then routes onward.
        '/': (context) => const OpeningSplash(),
        // Greeting splash: shown only right after a fresh login/register.
        '/splash': (context) => const SplashScreen(),
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/home': (context) => const ResidentHome(),
        '/reports': (context) => const MyReports(),
        '/map': (context) => const MapPage(
              category: '',
              description: '',
            ),
        '/profile': (context) => const Profile(),
        '/admin': (context) => const AdminHome(),
        '/report': (context) => const ReportPage(),
      },
    );
  }
}