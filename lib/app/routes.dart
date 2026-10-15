import 'package:flutter/material.dart';
import '../screens/splash_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/home_screen.dart';
import '../screens/notes_screen.dart';
import '../screens/tasks_screen.dart';
import '../screens/timetable_screen.dart';


class AppRoutes {
  // Route name constants
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String home = '/home';
  static const String notes = '/notes';
  static const String tasks = '/tasks';
  static const String timetable = '/timetable';


  // Map of route names to screens
  static Map<String, WidgetBuilder> get routes => {
    splash: (_) => const SplashScreen(),
    onboarding: (_) => const OnboardingScreen(),
    home: (_) => const HomeScreen(),
    notes: (_) => const NotesScreen(),
    tasks: (_) => const TasksScreen(),
    timetable: (_) => const TimetableScreen(),

  };
}
