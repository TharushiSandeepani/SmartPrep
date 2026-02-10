import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/main_nav.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/notification_service.dart';
import 'theme/colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService.initialize();
  runApp(const SmartPrepApp());
}

class SmartPrepApp extends StatelessWidget {
  const SmartPrepApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartPrep',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // 🌿 Use pastel mint theme
        colorScheme: const ColorScheme.light(
          primary: kTropicalGreen, // #1ea77b
          secondary: kMintGreen,
          onPrimary: Colors.white,
          onSecondary: Colors.black,
          surface: Colors.white,
          onSurface: kEmerald,
        ),

        // 🌸 Apply pastel background
        scaffoldBackgroundColor: kLightMint,

        // 🌈 Set global fonts
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            fontFamily: 'SummaryNotes',
            fontSize: 40,
            color: kTropicalGreen,
          ),
          headlineMedium: TextStyle(
            fontFamily: 'SummaryNotes',
            fontSize: 32,
            color: kTropicalGreen,
          ),
          titleLarge: TextStyle(
            fontFamily: 'SummaryNotes',
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: kTropicalGreen,
          ),
          bodyLarge: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16,
            color: Colors.black87,
          ),
          bodyMedium: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            color: Colors.black87,
          ),
          labelLarge: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),

        // 🌼 Buttons
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: kTropicalGreen,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),

        // 💚 Use Material 3
        useMaterial3: true,
      ),

      // 🧭 Auth-based navigation
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          return const MainNav();
        }

        return const LoginScreen();
      },
    );
  }
}
