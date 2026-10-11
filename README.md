# StudyMate - Student Productivity App

StudyMate is a clean, modern, and student-focused mobile productivity application built with Flutter.

---

## 📱 Features

- **Splash Screen**: Displays brand identity with a 3-second auto-navigation timer to onboarding.
- **Onboarding Screen**: Welcomes students and provides an entry point with a "Get Started" action.
- **Home Screen**: Central dashboard with quick navigation cards to Notes, Tasks, Timetable, and Profile.
- **Notes Screen**: Interactive notes list with subject categorization and an "Add Note" dialog.
- **Tasks Screen**: Study to-do list with interactive checkboxes to track completed tasks.
- **Timetable Screen**: Weekly class timetable organized by day tabs (Monday to Friday).
- **Profile Screen**: 
  - Circular avatar with cross-platform gallery image upload support (Flutter Web & Mobile).
  - Interactive profile editing for Name, Email, Class/Major, and Bio.
  - Edit Profile and Save actions with real-time UI updates.
  - Consistent design using the app's core design tokens.

---

## 📁 Project Structure

```text
lib/
├── app/
│   ├── app.dart           # Main MaterialApp configuration
│   └── routes.dart        # Route definitions and screen mapping
├── core/
│   ├── colors.dart        # App brand color palette
│   └── theme.dart         # Material 3 light theme definitions
├── screens/
│   ├── splash_screen.dart     # Auto-navigating splash screen
│   ├── onboarding_screen.dart # Welcome onboarding screen
│   ├── home_screen.dart       # Dashboard screen
│   ├── notes_screen.dart      # Study notes manager
│   ├── tasks_screen.dart      # Checkbox to-do list
│   ├── timetable_screen.dart  # Weekly class timetable
│   └── profile_screen.dart    # Editable student profile
└── main.dart              # App entry point
```

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (3.13+ or compatible)
- Dart SDK

### Installation & Run

1. Fetch dependencies:
   ```bash
   flutter pub get
   ```

2. Run the application:
   ```bash
   flutter run
   ```

3. Run automated tests:
   ```bash
   flutter test
   ```

