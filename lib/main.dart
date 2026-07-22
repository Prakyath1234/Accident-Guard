import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/login_screen.dart';
import 'services/database_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Local Mock DB / Session Persistence
  await DatabaseService.init();

  // Robust initialization of Firebase
  // If no Firebase configuration file is found, it will throw an exception,
  // which we catch gracefully so the app can run in mockup presentation mode.
  try {
    await Firebase.initializeApp();
    print("Firebase successfully initialized");
  } catch (e) {
    print("Firebase initialization skipped (Running in Mock Fallback Mode): $e");
  }

  runApp(const AccidentGuardApp());
}

class AccidentGuardApp extends StatelessWidget {
  const AccidentGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Accident Guard System',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE53935), // Emergency Red
          brightness: Brightness.dark,
          primary: const Color(0xFFE53935),
          secondary: const Color(0xFFFF8A80),
          surface: const Color(0xFF1E1E24),
          background: const Color(0xFF121214),
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: Colors.white),
          titleLarge: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, color: Colors.white),
          bodyLarge: TextStyle(fontFamily: 'Inter', color: Color(0xFFD1D1D6)),
          bodyMedium: TextStyle(fontFamily: 'Inter', color: Color(0xFFAEAEB2)),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF1E1E24),
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      home: const LoginScreen(),
    );
  }
}
