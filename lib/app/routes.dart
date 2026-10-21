import 'package:flutter/material.dart';
import '../screens/splash_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/main_shell.dart';
import '../screens/notification_settings_screen.dart';
import '../screens/clock_screen.dart';
import '../screens/calculator_screen.dart';
import '../screens/pdf_library_screen.dart';
import '../screens/vault_lock_screen.dart';

class AppRoutes {
  // Route name constants
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String home = '/home';
  static const String notifications = '/notifications';
  static const String clock = '/clock';
  static const String calculator = '/calculator';
  static const String pdfs = '/pdfs';
  static const String vault = '/vault';

  // notes / tasks / timetable are no longer separate named routes —
  // they are rendered inside MainShell via IndexedStack.

  // Map of route names to screens
  static Map<String, WidgetBuilder> get routes => {
    splash: (_) => const SplashScreen(),
    onboarding: (_) => const OnboardingScreen(),
    home: (_) => const MainShell(),
    notifications: (_) => const NotificationSettingsScreen(),
    clock: (_) => const ClockScreen(),
    calculator: (_) => const CalculatorScreen(),
    pdfs: (_) => const PdfLibraryScreen(),
    vault: (_) => const VaultLockScreen(),
  };
}
