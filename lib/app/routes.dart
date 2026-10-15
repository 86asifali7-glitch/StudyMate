import 'package:flutter/material.dart';
import '../screens/splash_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/main_shell.dart';


class AppRoutes {
  // Route name constants
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String home = '/home';

  // notes / tasks / timetable are no longer separate named routes —
  // they are rendered inside MainShell via IndexedStack.


  // Map of route names to screens
  static Map<String, WidgetBuilder> get routes => {
    splash: (_) => const SplashScreen(),
    onboarding: (_) => const OnboardingScreen(),
    home: (_) => const MainShell(),
  };
}
