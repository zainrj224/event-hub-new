# 🚀 Migration Guide: Separating Frontend & Backend

This guide helps you migrate your Event Hub app to use the separated structure.

## 📋 Current vs New Structure

### BEFORE (Mixed)
```
lib/
└── features/
    └── events/
        ├── presentation/    # UI mixed here
        ├── data/           # Backend mixed here
        └── domain/         # Backend mixed here
```

### AFTER (Separated)
```
Event-Hub-fixed/
├── lib/                      # Main app (unchanged)
│   ├── main.dart
│   ├── main_shell.dart
│   └── core/
│       ├── routes/
│       └── constants/
│
├── frontend_ui/             # 🎨 All UI files
│   ├── screens/
│   ├── widgets/
│   └── theme/
│
└── backend_logic/           # ⚙️ All logic files
    ├── models/
    ├── repositories/
    ├── services/
    ├── entities/
    └── utils/
```

## 🎯 Quick Start (3 Options)

### Option 1: Keep Current Structure (No Changes)
Your current `lib/` folder works perfectly as-is. Use `frontend_ui/` and `backend_logic/` folders as **reference** when redesigning UI in the future.

### Option 2: Gradual Migration (Recommended)
Migrate one feature at a time while keeping the app running.

### Option 3: Full Migration (Advanced)
Move everything to the new structure in one go.

## 🔧 Option 2: Gradual Migration (Step-by-Step)

### Step 1: Set Up New Folders
```bash
# Already done! You have:
# ✅ frontend_ui/ with all screens, widgets, theme
# ✅ backend_logic/ with all models, services, utils
```

### Step 2: Update `pubspec.yaml`
No changes needed! Your dependencies stay the same.

### Step 3: Migrate One Screen at a Time

Let's migrate **Home Screen** as an example:

#### A. Current imports (in `lib/features/home/presentation/screens/home_tab.dart`):
```dart
import '../../../events/data/models/event_model.dart';
import '../../../events/presentation/widgets/event_card.dart';
import '../../../../core/theme/app_theme.dart';
```

#### B. New imports (referencing separated files):
```dart
import 'package:event_hub/backend_logic/models/event_model.dart';
import 'package:event_hub/frontend_ui/widgets/cards/event_card.dart';
import 'package:event_hub/frontend_ui/theme/app_theme.dart';
```

#### C. Update the file:
1. Open `lib/features/home/presentation/screens/home_tab.dart`
2. Replace relative imports with package imports
3. Test that it compiles: `flutter run`
4. If it works, move to next screen!

### Step 4: Update Routes

In `lib/core/routes/app_routes.dart`, change imports:

```dart
// OLD
import '../../features/auth/presentation/screens/sign_in_screen.dart';
import '../../features/events/presentation/screens/event_detail_screen.dart';

// NEW
import 'package:event_hub/frontend_ui/screens/auth/sign_in_screen.dart';
import 'package:event_hub/frontend_ui/screens/events/event_detail_screen.dart';
```

### Step 5: Verify Everything Works
```bash
flutter clean
flutter pub get
flutter run
```

## 🎨 Option 3: Using Separated Files for UI Redesign

You DON'T need to change your current `lib/` structure. Instead, use the separated files as a reference:

### Scenario: You want to redesign the Event Card

1. **Current working file**: `lib/features/events/presentation/widgets/event_card.dart`
2. **Reference file**: `frontend_ui/widgets/cards/event_card.dart` (same file, easier to find)

3. **Create new design**:
```dart
// Create: frontend_ui/widgets/cards/modern_event_card.dart
import 'package:flutter/material.dart';
import 'package:event_hub/backend_logic/models/event_model.dart';

class ModernEventCard extends StatelessWidget {
  final Event event;
  
  @override
  Widget build(BuildContext context) {
    return Container(
      // NEW MODERN DESIGN HERE
      // Uses same Event model from backend_logic
    );
  }
}
```

4. **Swap in your app**:
```dart
// lib/features/home/presentation/screens/home_tab.dart

// OLD
import '../../../events/presentation/widgets/event_card.dart';

// NEW  
import 'package:event_hub/frontend_ui/widgets/cards/modern_event_card.dart';

// In build method:
// OLD: EventCard(event: event)
// NEW: ModernEventCard(event: event)
```

5. Backend stays untouched! Data fetching, Firebase queries, all unchanged.

## 📦 Package Import Setup

To use package imports like `import 'package:event_hub/...'`, ensure your `pubspec.yaml` has:

```yaml
name: event_hub  # Or event_discovery_app

# No changes needed for dependencies!
```

Then imports work as:
- `package:event_hub/frontend_ui/screens/auth/sign_in_screen.dart`
- `package:event_hub/backend_logic/models/event_model.dart`

## ✅ Migration Checklist

- [ ] Files separated into `frontend_ui/` and `backend_logic/` ✅ (Already done!)
- [ ] Understand new folder structure (read README files)
- [ ] Decide: Keep current structure OR migrate?
- [ ] If migrating: Update imports one screen at a time
- [ ] Test app builds after each change
- [ ] Update routes to use new imports
- [ ] Run `flutter clean && flutter pub get`
- [ ] Test all features work correctly

## 🚨 Common Issues & Fixes

### Issue 1: Import not found
```
Error: Couldn't resolve the 'package:event_hub/frontend_ui/...'
```
**Fix**: Make sure `name: event_hub` in pubspec.yaml matches your imports

### Issue 2: Relative imports break
```
Error: Can't find '../../../backend/...'
```
**Fix**: Use package imports instead:
```dart
import 'package:event_hub/backend_logic/models/event_model.dart';
```

### Issue 3: Duplicate files
```
Error: 'Event' is defined in multiple files
```
**Fix**: Remove old file after migration, or rename new file

## 🎯 Recommended Approach

**For you right now**: Keep using `lib/` as-is. When you're ready to redesign UI:

1. Look at `frontend_ui/` to find the screen you want to redesign
2. Create new version with modern UI
3. Import it using package imports
4. Test and swap!

The separation is done and ready - you can use it when needed!

## 📞 Need Help?

Each folder has a detailed README:
- `frontend_ui/README.md` - UI guidelines and examples
- `backend_logic/README.md` - Backend structure and patterns
- `PROJECT_STRUCTURE.md` - Overall architecture

## 🎉 Benefits You Get

✅ **Now**: Clear organization, easy to find files  
✅ **Future**: Quick UI redesigns without touching logic  
✅ **Team**: Designers work on `frontend_ui/`, developers on `backend_logic/`  
✅ **Scalability**: Add new UI themes easily  
✅ **Maintenance**: Changes in one don't break the other
