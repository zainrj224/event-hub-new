import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_notifier.dart';
import 'core/routes/app_routes.dart';
import 'features/auth/presentation/screens/sign_in_screen.dart';
import 'core/cache/cache_service.dart';
import 'main_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Init cache — wrapped so a missing package never blanks the app
  try {
    await CacheService.instance.init();
  } catch (_) {}

  runApp(const EventHubApp());
}

class EventHubApp extends StatelessWidget {
  const EventHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeNotifier.instance,
      builder: (context, _) {
        return MaterialApp(
          title: 'Event Hub',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light().copyWith(
            textTheme: GoogleFonts.interTextTheme(AppTheme.light().textTheme),
          ),
          darkTheme: AppTheme.dark().copyWith(
            textTheme: GoogleFonts.interTextTheme(AppTheme.dark().textTheme),
          ),
          themeMode: ThemeNotifier.instance.value,
          onGenerateRoute: AppRoutes.generateRoute,
          home: const AuthGate(),
        );
      },
    );
  }
}

/// AuthGate as StatefulWidget — critical fix.
///
/// As StatelessWidget, build() is called many times. Each call passes a
/// potentially new authStateChanges() Stream object to StreamBuilder.
/// StreamBuilder compares streams by identity: a new object means it cancels
/// the old subscription and creates a new one, briefly emitting
/// ConnectionState.waiting. During Flutter Web route transitions, build() fires
/// rapidly → multiple subscriptions pile up → CanvasKit is overwhelmed → freeze.
///
/// As StatefulWidget, the stream is created ONCE in initState() and reused,
/// so StreamBuilder never resubscribes unnecessarily.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  // Single stream instance — never recreated during rebuilds
  final Stream<User?> _authStream = FirebaseAuth.instance.authStateChanges();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData && snapshot.data != null) {
          return const MainShell();
        }
        return const SignInScreen();
      },
    );
  }
}
