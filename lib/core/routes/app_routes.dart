import 'package:flutter/material.dart';
import '../../features/auth/presentation/screens/sign_in_screen.dart';
import '../../features/auth/presentation/screens/sign_up_screen.dart';
import '../../features/events/domain/entities/event_entity.dart';
import '../../features/events/presentation/screens/event_detail_screen.dart';
import '../../features/profile/presentation/screens/my_events_screen.dart';
import '../../features/profile/presentation/screens/saved_events_screen.dart';
import '../../features/profile/presentation/screens/settings_screen.dart';
import '../../features/events/presentation/screens/search_screen.dart';
import '../../main_shell.dart';

class AppRoutes {
  AppRoutes._();

  static const String signIn       = '/signin';
  static const String signUp       = '/signup';
  static const String main         = '/main';
  static const String eventDetail  = '/event-detail';
  static const String createEvent  = '/create-event';
  static const String myEvents     = '/my-events';
  static const String savedEvents  = '/saved-events';
  static const String settings     = '/settings';
  static const String search       = '/search';

  static Route<dynamic> generateRoute(RouteSettings routeSettings) {
    switch (routeSettings.name) {
      case signIn:
        return MaterialPageRoute(
            builder: (_) => const SignInScreen(), settings: routeSettings);
      case signUp:
        return MaterialPageRoute(
            builder: (_) => const SignUpScreen(), settings: routeSettings);
      case main:
        return MaterialPageRoute(
            builder: (_) => const MainShell(), settings: routeSettings);
      case eventDetail:
        final event = routeSettings.arguments as Event;
        return MaterialPageRoute(
            builder: (_) => EventDetailScreen(event: event),
            settings: routeSettings);
      case myEvents:
        return MaterialPageRoute(
            builder: (_) => const MyEventsScreen(), settings: routeSettings);
      case savedEvents:
        return MaterialPageRoute(
            builder: (_) => const SavedEventsScreen(), settings: routeSettings);
      case settings:
        return MaterialPageRoute(
            builder: (_) => const SettingsScreen(), settings: routeSettings);
      case search:
        return MaterialPageRoute(
            builder: (_) => const SearchScreen(), settings: routeSettings);
      default:
        return MaterialPageRoute(
            builder: (_) => const SignInScreen(), settings: routeSettings);
    }
  }
}
