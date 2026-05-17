import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;

/// Exception class for authentication errors
class AuthException implements Exception {
  final String message;
  final String code;

  AuthException(this.message, {this.code = 'unknown'});

  @override
  String toString() => message;
}

/// Singleton service for authentication operations
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;

  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  AuthService._internal();

  /// Get current authenticated user
  User? get currentUser => _firebaseAuth.currentUser;

  /// Stream of authentication state changes
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  /// Check if user is authenticated
  bool get isAuthenticated => currentUser != null;

  /// Get current user ID
  String? get currentUserId => currentUser?.uid;

  /// Get current user email
  String? get currentUserEmail => currentUser?.email;

  /// Get current user display name
  String? get currentUserDisplayName => currentUser?.displayName;

  /// Sign up with email and password
  Future<UserCredential> signUpWithEmailPassword({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      // Update display name if provided.
      // Wrapped in try-catch because updateDisplayName() can throw silently
      // on Flutter Web, which would crash the sign-up flow even though the
      // account was created successfully.
      if (displayName != null && displayName.isNotEmpty) {
        try {
          await userCredential.user?.updateDisplayName(displayName);
        } catch (e) {
          // Non-critical — account is created, display name can be set later
          debugPrint('[AuthService] updateDisplayName failed (non-fatal): $e');
        }
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw AuthException('Sign up failed: $e');
    }
  }

  /// Sign in with email and password
  Future<UserCredential> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw AuthException('Sign in failed: $e');
    }
  }

  /// Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // Web platform
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        final userCredential = await _firebaseAuth.signInWithPopup(googleProvider);
        return userCredential;
      } else {
        // Mobile platforms
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

        if (googleUser == null) {
          throw AuthException('Google sign-in cancelled', code: 'cancelled');
        }

        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        final userCredential = await _firebaseAuth.signInWithCredential(credential);
        return userCredential;
      }
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Google sign-in failed: $e');
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await Future.wait([
        _firebaseAuth.signOut(),
        _googleSignIn.signOut(),
      ]);
    } catch (e) {
      throw AuthException('Sign out failed: $e');
    }
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw AuthException('Failed to send reset email: $e');
    }
  }

  /// Update user profile
  Future<void> updateProfile({String? displayName, String? photoURL}) async {
    try {
      final user = currentUser;
      if (user == null) {
        throw AuthException('No user logged in');
      }

      if (displayName != null) {
        await user.updateDisplayName(displayName);
      }
      if (photoURL != null) {
        await user.updatePhotoURL(photoURL);
      }

      await user.reload();
    } catch (e) {
      throw AuthException('Failed to update profile: $e');
    }
  }

  /// Delete user account
  Future<void> deleteAccount() async {
    try {
      final user = currentUser;
      if (user == null) {
        throw AuthException('No user logged in');
      }

      await user.delete();
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw AuthException('Failed to delete account: $e');
    }
  }

  /// Handle Firebase Auth exceptions
  AuthException _handleAuthException(FirebaseAuthException e) {
    String message;
    switch (e.code) {
      case 'weak-password':
        message = 'The password is too weak';
        break;
      case 'email-already-in-use':
        message = 'An account already exists with this email';
        break;
      case 'invalid-email':
        message = 'The email address is invalid';
        break;
      case 'user-disabled':
        message = 'This account has been disabled';
        break;
      case 'user-not-found':
        message = 'No account found with this email';
        break;
      case 'wrong-password':
        message = 'Incorrect password';
        break;
      case 'too-many-requests':
        message = 'Too many failed attempts. Please try again later';
        break;
      case 'operation-not-allowed':
        message = 'This sign-in method is not enabled';
        break;
      case 'network-request-failed':
        message = 'Network error. Please check your connection';
        break;
      default:
        message = e.message ?? 'Authentication failed';
    }
    return AuthException(message, code: e.code);
  }
}
