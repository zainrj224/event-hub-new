import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_notifier.dart';
import 'core/routes/app_routes.dart';
import 'features/auth/presentation/screens/sign_in_screen.dart';
import 'main_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
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

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  // Single stable stream — never recreated on rebuild
  final Stream<User?> _authStream = FirebaseAuth.instance.authStateChanges();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFFF9FAFB),
            body: Center(
              child: CircularProgressIndicator(
                color: AppColors.purple,
              ),
            ),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text('Error: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red)),
            ),
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
