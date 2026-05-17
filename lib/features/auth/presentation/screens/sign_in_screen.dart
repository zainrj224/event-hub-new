import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/gradient_button.dart';
import '../../../../core/widgets/inputs/custom_text_field.dart';
import 'sign_up_screen.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ─── Translates Firebase error codes into readable messages ───────────────
  String _friendlyError(dynamic e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'user-not-found':
        case 'invalid-credential':
        case 'wrong-password':
          return 'Invalid email or password. Please check your credentials.';
        case 'invalid-email':
          return 'The email address is not valid.';
        case 'user-disabled':
          return 'This account has been disabled.';
        case 'too-many-requests':
          return 'Too many failed attempts. Please try again later.';
        case 'operation-not-allowed':
          return 'Email/password sign-in is not enabled in Firebase Console.\n'
              'Go to: Authentication → Sign-in method → Email/Password → Enable.';
        case 'network-request-failed':
          return 'Network error. Check your internet connection.';
        default:
          return 'Sign-in failed (${e.code}): ${e.message}';
      }
    }
    return 'Unexpected error: $e';
  }

  // ─── Email / Password sign-in ─────────────────────────────────────────────
  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      // AuthGate StreamBuilder detects the sign-in and switches to MainShell
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = _friendlyError(e));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Google sign-in ───────────────────────────────────────────────────────
  Future<void> _signInWithGoogle() async {
    setState(() {
      _isGoogleLoading = true;
      _errorMessage = null;
    });

    try {
      GoogleAuthProvider googleProvider = GoogleAuthProvider();
      await FirebaseAuth.instance.signInWithPopup(googleProvider);
      // AuthGate StreamBuilder detects the sign-in and switches to MainShell
    } catch (e) {
      if (mounted) {
        final msg = _friendlyError(e);
        if (!msg.contains('cancelled')) {
          setState(() => _errorMessage = msg);
        }
      }
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() =>
          _errorMessage = 'Enter your email above first, then tap Forgot password.');
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Password reset email sent. Check your inbox.')),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = _friendlyError(e));
    }
  }

  // ─── UI ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 48),
                _buildHeader(),
                const SizedBox(height: 40),

                // Email
                CustomTextField(
                  controller: _emailController,
                  label: 'Email',
                  hint: 'you@example.com',
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  prefixIcon: const Icon(Icons.email_outlined),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Enter your email';
                    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v.trim())) {
                      return 'Enter a valid email';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Password
                CustomTextField(
                  controller: _passwordController,
                  label: 'Password',
                  hint: '••••••••',
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter your password';
                    return null;
                  },
                ),

                // Forgot password
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _forgotPassword,
                    child: const Text('Forgot password?'),
                  ),
                ),

                // ── Error banner ─────────────────────────────────────────
                if (_errorMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.shade300, width: 1.5),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.error_outline,
                            color: Colors.red.shade700, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(
                                color: Colors.red.shade800,
                                fontSize: 13,
                                height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Sign In button
                GradientButton(
                  text: 'Sign In',
                  onPressed: _signIn,
                  isLoading: _isLoading,
                  width: double.infinity,
                ),

                const SizedBox(height: 20),

                // Divider
                Row(
                  children: [
                    Expanded(
                        child: Divider(
                            color: isDark ? Colors.white24 : Colors.black12)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('or',
                          style: TextStyle(
                              color: isDark
                                  ? Colors.white54
                                  : AppColors.lightTextSecondary)),
                    ),
                    Expanded(
                        child: Divider(
                            color: isDark ? Colors.white24 : Colors.black12)),
                  ],
                ),

                const SizedBox(height: 20),

                // Google button
                _GoogleSignInButton(
                  onPressed: _signInWithGoogle,
                  isLoading: _isGoogleLoading,
                ),

                const SizedBox(height: 32),

                // Sign up link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Don't have an account? ",
                        style: TextStyle(
                            color: isDark
                                ? Colors.white70
                                : AppColors.lightTextSecondary)),
                    GestureDetector(
                      onTap: () =>
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SignUpScreen())),
                      child: ShaderMask(
                        shaderCallback: (bounds) =>
                            AppColors.primaryGradient.createShader(bounds),
                        child: const Text('Sign Up',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradientDiagonal,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.purple.withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(Icons.event_rounded, color: Colors.white, size: 36),
        ),
        const SizedBox(height: 20),
        ShaderMask(
          shaderCallback: (bounds) =>
              AppColors.primaryGradient.createShader(bounds),
          child: const Text(
            'Event Hub',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Welcome back! Sign in to continue.',
          style: TextStyle(color: AppColors.lightTextSecondary, fontSize: 15),
        ),
      ],
    );
  }
}

// ─── Google Sign-In button ────────────────────────────────────────────────────
class _GoogleSignInButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isLoading;
  const _GoogleSignInButton(
      {required this.onPressed, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 56,
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          side:
              BorderSide(color: isDark ? Colors.white24 : Colors.black12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor:
              isDark ? const Color(0xFF1F2937) : Colors.white,
        ),
        child: isLoading
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _GoogleLogo(),
                  const SizedBox(width: 12),
                  Text(
                    'Continue with Google',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _GoogleLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
        width: 22, height: 22, child: CustomPaint(painter: _GoogleLogoPainter()));
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;
    Paint arc(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.18;

    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r),
        -2.356, 1.571, false, arc(const Color(0xFF4285F4)));
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r),
        2.356, 1.571, false, arc(const Color(0xFFEA4335)));
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r),
        0.785, 1.571, false, arc(const Color(0xFFFBBC05)));
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r),
        -0.785, 1.571, false, arc(const Color(0xFF34A853)));
    canvas.drawRect(
      Rect.fromLTWH(cx, cy - size.height * 0.09, r * 0.95, size.height * 0.18),
      Paint()..color = const Color(0xFF4285F4),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
