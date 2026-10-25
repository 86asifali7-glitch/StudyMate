# StudyMate - Student Productivity App

StudyMate is a clean, modern, and student-focused mobile productivity application built with Flutter, featuring a consistent premium **Blue & White** design system.

---

## 🎨 Design System

StudyMate follows a cohesive, professional Blue & White visual identity across all screens and components:

- **Primary Blue**: `#2563EB` (vibrant primary accent for selected tabs, primary buttons, badges, and key icons)
- **Soft Light-Blue Tint**: `#EFF6FF` (background containers, badges, banners, and circular icon wells)
- **Secondary Track / Accent Tint**: `#DBEAFE` (borders, progress tracks, and highlight accents)
- **Main Slate Text**: `#1E293B` (headings and primary labels)
- **Muted Slate Text**: `#64748B` (subtitles, secondary info, timestamps, and icons)
- **Background**: `#FFFFFF` (clean white page surface)
- **Subtle Borders**: `#E2E8F0` (consistent card borders and dividers)

---

## 📱 Features & Screens

### 1. Home Screen
- **Header**: StudyMate branding with book logo and notification bell shortcut.
- **Motivational Quote Banner**: Soft blue gradient banner featuring rotating study quotes every 15 seconds with smooth transitions and study-themed artwork.
- **Quick Access Shortcuts**: Uniformly styled, light-blue rounded action shortcuts with real-time badges for **Clock**, **Calculator**, **My PDFs**, and **Personal Vault**.
- **Upcoming Schedule Preview**: Dynamic preview card displaying today's classes and timing.
- **Recent Notes & Tasks**: Quick overview cards synchronized live with local app storage.

### 2. My Notes Screen & Editor
- **Header & Saved Count**: Displays total note count with quick search and options menu.
- **Inspirational Banner**: "Organize your thoughts - Notes make learning easier" banner with quick Add Note (+) action.
- **Subject Categories & "See all"**: Horizontally scrollable row of subject category cards (Physics, Mathematics, English, Chemistry, Biology, Computer Science, History) with dynamic note counts. Tap **See all** to view the full category list and filter notes.
- **Rich-Text Editor**:
  - Full formatting toolbar: Bold, Italic, Underline, Bulleted List, Numbered List, Formulas.
  - Multi-paragraph alignment options (Left, Center, Right, Justify) with paragraph-level selection isolation.
  - Automatic note autosave and local persistence via `AppDataService` and `SharedPreferences`.

### 3. My Tasks Screen
- **Header & Subtitle**: "My Tasks - Stay focused, one task at a time."
- **Task Progress Card**: Dynamic progress card showing completed vs. total tasks (e.g., "2 of 5 completed"), completion percentage, and an animated progress bar.
- **Filter Tabs**: Independent, isolated filters:
  - **All**: View all tasks.
  - **Today**: Tasks due today.
  - **Upcoming**: Future-due incomplete tasks.
  - **Completed**: Finished tasks.
- **Interactive Task Lists**:
  - **Due Soon**: Active incomplete tasks with interactive rounded checkboxes, immediate visual feedback, and smooth completion reordering.
  - **Completed**: Finished tasks with struck-through text and completion timestamps.
  - Smooth task deletion with floating "Undo" action.
  - Floating Action Button (+) with due date presets and priority tags.

### 4. Timetable Screen
- **Header & Actions**: "My Timetable - Your week, planned clearly" with top-right quick actions to add classes or clear schedule with confirmation.
- **Weekday Selector**: Monday to Friday horizontal selector with real-time class counts:
  - Active day highlighted in primary blue (`#2563EB`) with white text and badge.
  - Inactive days rendered in clean, simple style with subtle muted text.
  - Strictly isolated tap effects bounded to the tapped day without cross-tab ripples.
- **Daily Summary Card**: Rounded light-blue summary card with schedule progress bar, selected day's class count, and earliest-to-latest time span.
- **Reference-Style Class Cards**:
  - White rounded cards (`18px` radius) with subtle borders (`#E2E8F0`) and soft shadows.
  - Slim blue vertical accent stripe (`#2563EB`) along the left edge.
  - Light-blue rounded-square badge (`#EFF6FF`) holding primary blue clock icon (`Icons.access_time_rounded`).
  - Class name in bold slate (`#1E293B`), schedule time (`#64748B`), and room/location (`Icons.location_on_outlined`).
  - Separate circular action buttons for editing (`#F1F5F9`) and deleting (`#FEF2F2`) with subtle interaction effects.
  - Full CRUD support with time pickers and local persistence.

### 5. Utilities & Quick Access
- **Clock**: Multi-functional world clock, stopwatch, and timer.
- **Calculator**: Clean calculator supporting basic arithmetic and order of operations.
- **My PDFs & Personal Vault**: Document management and secure student vault.
- **Settings & Notifications**: Manage class reminders and audio preferences via `NotificationService` and `SoundService`.

### 6. Bottom Navigation
- Fixed 4-tab bottom navigation (**Home**, **Notes**, **Tasks**, **Timetable**).
- Active tab pill indicator with blue tint and bold label.
- Isolated tap feedback preventing shared ripple or delay bugs.

---

## 📁 Project Structure

```text
lib/
├── app/
│   ├── app.dart               # Main MaterialApp configuration & theme setup
│   └── routes.dart            # Centralized route definitions
├── core/
│   ├── colors.dart            # Design tokens & color constants
│   └── theme.dart             # Material 3 light theme definitions
├── screens/
│   ├── splash_screen.dart     # Auto-navigating splash screen
│   ├── onboarding_screen.dart # Welcome onboarding screen
│   ├── home_screen.dart       # Dashboard with quotes & Quick Access
│   ├── notes_screen.dart      # Rich notes manager & subject categories
│   ├── tasks_screen.dart      # Task manager with progress card & filters
│   ├── timetable_screen.dart  # Weekly timetable with reference card design
│   ├── clock_screen.dart      # Clock, timer, and stopwatch
│   ├── calculator_screen.dart # Student calculator
│   ├── pdf_screen.dart        # PDF viewer & documents manager
│   ├── vault_screen.dart      # Secure personal vault
│   ├── profile_screen.dart    # Editable student profile
│   └── settings_screen.dart   # Notification & sound settings
├── services/
│   ├── app_data_service.dart     # Centralized persistence & reactive state
│   ├── notification_service.dart # Local schedule & task notifications
│   └── sound_service.dart        # Audio feedback & sound settings
└── main.dart                  # Application entry point
```

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (3.13+ or compatible)
- Dart SDK (3.0+ or compatible)

### Installation & Run

1. **Fetch dependencies**:
   ```bash
   flutter pub get
   ```

2. **Run static analysis**:
   ```bash
   flutter analyze
   ```

3. **Run automated test suite**:
   ```bash
   flutter test
   ```

4. **Launch the application**:
   ```bash
   flutter run
   ```
