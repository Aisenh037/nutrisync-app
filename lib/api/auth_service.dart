import 'package:firebase_auth/firebase_auth.dart';

/// A result class for authentication actions, containing either a user or an error message.
class AuthResult {
  final User? user;
  final String? error;
  AuthResult({this.user, this.error});
}

/// Service for handling authentication with Firebase Auth.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Stream of authentication state changes.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Sign in with email and password.
  /// Returns [AuthResult] with user or error message.
  Future<AuthResult> signInWithEmail(String email, String password) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(email: email, password: password);
      return AuthResult(user: result.user);
    } on FirebaseAuthException catch (e) {
      return AuthResult(error: e.message ?? 'Sign in failed');
    } catch (e) {
      return AuthResult(error: 'Sign in failed: $e');
    }
  }

  /// Sign up with email and password.
  /// Returns [AuthResult] with user or error message.
  Future<AuthResult> signUpWithEmail(String email, String password) async {
    try {
      final result = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      return AuthResult(user: result.user);
    } on FirebaseAuthException catch (e) {
      return AuthResult(error: e.message ?? 'Sign up failed');
    } catch (e) {
      return AuthResult(error: 'Sign up failed: $e');
    }
  }

  /// Sign out the current user.
  Future<void> signOut() async {
    await _auth.signOut();
  }
}