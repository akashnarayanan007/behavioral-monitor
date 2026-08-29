import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/home_screen.dart';
import 'screens/consent_screen.dart';
import 'services/notification_service.dart';
import 'screens/mood_input_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  debugPrint("--- 🚀 APP STARTING ---");
  
  // 1. Mandatory for async initialization
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint("--- 🟢 Widgets Binding Initialized ---");

  // 2. Check for User Consent
  debugPrint("--- 🔍 Fetching SharedPreferences ---");
  final prefs = await SharedPreferences.getInstance();
  final bool hasConsented = prefs.getBool('hasConsented') ?? false;
  debugPrint("--- ✅ Consent Status: $hasConsented ---");

  // 3. Initialize background services with error handling
  debugPrint("--- 🔍 Initializing Notification Service ---");
  try {
    await NotificationService.init((payload) {
      if (payload == "mood") {
        navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (context) => const MoodInputScreen()),
        );
      }
    });
    debugPrint("--- ✅ Notification Service Ready ---");
  } catch (e) {
    debugPrint("--- ❌ Background Service Error: $e ---");
  }

  debugPrint("--- 🏁 Running App ---");
  runApp(BehaviorMonitorApp(hasConsented: hasConsented));
}

class BehaviorMonitorApp extends StatelessWidget {
  final bool hasConsented;
  const BehaviorMonitorApp({super.key, required this.hasConsented});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: "MindMatrix",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF4A90E2),
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF4A90E2),
          elevation: 0,
          centerTitle: true,
        ),
        cardTheme: CardThemeData(
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4A90E2),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      home: hasConsented ? const HomeScreen() : const ConsentScreen(),
    );
  }
}
