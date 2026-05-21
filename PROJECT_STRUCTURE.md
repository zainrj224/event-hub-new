# Event Hub - Project Structure

## 🎨 Frontend (UI) - `/frontend_ui`
All visual components, screens, and widgets that can be redesigned without affecting business logic.

### Structure:
```
frontend_ui/
├── screens/          # All app screens
│   ├── auth/        # Sign in, Sign up, Onboarding
│   ├── home/        # Home tab
│   ├── explore/     # Explore tab  
│   ├── events/      # Event detail, Create event
│   └── profile/     # Profile, Settings, My Events
├── widgets/         # Reusable UI components
│   ├── cards/       # Event cards, User cards
│   ├── buttons/     # Custom buttons
│   ├── inputs/      # Form fields
│   └── common/      # Loading, Empty states
└── theme/           # Colors, Typography, Styles

**Purpose:** Easy UI redesign - change colors, layouts, animations without touching business logic.
```

## ⚙️ Backend (Logic) - `/backend_logic`
Business logic, data models, repositories, and services that handle app functionality.

### Structure:
```
backend_logic/
├── models/          # Data models (Event, User, etc.)
├── repositories/    # Data access layer (Firestore queries)
├── services/        # Business logic (Auth, Location, Cache)
├── entities/        # Domain entities
└── utils/          # Helpers, Validators, Formatters

**Purpose:** App functionality - authentication, data fetching, validation, caching.
```

## 📱 Current Integration - `lib/`
The main app structure that connects frontend and backend.

```
lib/
├── main.dart                    # App entry point
├── main_shell.dart              # Bottom navigation shell
├── firebase_options.dart        # Firebase config
└── core/
    ├── routes/                  # Navigation
    └── constants/              # App-wide constants
```

## 🔄 How to Upgrade UI (Future)

1. **Design New UI** → Work only in `/frontend_ui`
2. **Keep Imports Same** → Backend imports remain unchanged
3. **Test Individually** → UI screens can be tested in isolation
4. **Swap Screens** → Replace old screen with new screen in routes

### Example: Redesigning Home Screen
```dart
// OLD (before separation)
import '../../../events/data/models/event_model.dart';  // ❌ UI mixed with data

// NEW (after separation)  
import 'package:event_hub/backend_logic/models/event_model.dart';  // ✅ Clear separation
```

## 📋 Migration Checklist

- [ ] Move all `presentation/screens` → `frontend_ui/screens`
- [ ] Move all `presentation/widgets` → `frontend_ui/widgets`
- [ ] Move `theme/` → `frontend_ui/theme`
- [ ] Move `data/models` → `backend_logic/models`
- [ ] Move `data/repositories` → `backend_logic/repositories`
- [ ] Move `domain/entities` → `backend_logic/entities`
- [ ] Move `shared/services` → `backend_logic/services`
- [ ] Update all imports to use new structure
- [ ] Test app builds successfully

## 🎯 Benefits

✅ **Clear Separation** - Designers work on UI, developers on logic  
✅ **Easy Redesign** - Swap entire UI without touching backend  
✅ **Better Organization** - Find files faster  
✅ **Scalable** - Add new UI themes easily  
✅ **Team Collaboration** - No merge conflicts between UI and logic changes
