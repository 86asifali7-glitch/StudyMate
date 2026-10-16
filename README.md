# StudyMate - Student Productivity App

StudyMate is a clean, modern, and student-focused mobile productivity application built with Flutter.

---

## 📱 Features

- **Splash Screen**: Displays brand identity with a 3-second auto-navigation timer to onboarding.
- **Onboarding Screen**: Welcomes students and provides an entry point with a "Get Started" action.
- **Home Screen**: Central dashboard featuring greeting, upcoming schedule card, synchronized live stats, and Quick Access navigation cards with dynamic item counts.
- **Notes Screen & Editor**: Apple Notes-inspired layout with subject-coded icon badges, real-time search, note creation dialog, deletion, and full rich-text editor (Bold, Italic, Underline, Bulleted List, Numbered List, Formulas) with local storage persistence.
- **Tasks Screen**: Modern task manager featuring:
  - Clean pastel aesthetic with segmented filter tabs (**All Tasks** and **Completed**).
  - Smooth, isolated hover states, mouse pointer cursors, and touch/click feedback across all cards, buttons, and checkboxes.
  - Isolated card and tab gesture handling preventing cross-element blinking or ghost selection.
  - Interactive rounded checkbox with strikethrough completion toggling.
  - Quick task deletion with "Undo" snackbar action.
  - Floating Action Button (+) with quick due date preset chips (`Due Tomorrow`, `Due Friday`, `Due Sunday`, etc.).
  - Top action menu to mark all tasks completed, clear completed tasks, or reset sample data.
- **Timetable Screen**: Weekly class schedule manager featuring:
  - Clean lavender-accented card UI matching the reference design.
  - Day selector (`Mon`, `Tue`, `Wed`, `Thu`, `Fri`) with active purple indicator bar.
  - Class cards displaying subject title, formatted schedule duration, lavender clock icon badge, inline edit pencil, and coral trash delete button.
  - Interactive "Add Class" rounded lavender header button with subject name, day selection, and start/end time pickers.
  - SharedPreferences data persistence and Undo deletion action.
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

