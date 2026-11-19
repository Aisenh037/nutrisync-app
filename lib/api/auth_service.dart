import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../core/error/app_exception.dart';

/// Result type kept for backwards compat with existing UI consumers.
/// New code should catch [AuthException] directly instead.
class AuthResult {
  final User? user;
  final String? error;
  AuthResult({this.user, this.error});

  bool get isSuccess => user != null && error == null;
}

/// Service for handling authentication with Firebase Auth.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<AuthResult> signInWithEmail(String email, String password) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      return AuthResult(user: result.user);
    } on FirebaseAuthException catch (e) {
      final ex = AuthException(e.message ?? 'Sign in failed', code: e.code, cause: e);
      ex.log(context: {'email': email});
      return AuthResult(error: ex.userMessage);
    } catch (e) {
      const ex = AuthException('Sign in failed');
      return AuthResult(error: ex.userMessage);
    }
  }

  Future<AuthResult> signUpWithEmail(String email, String password) async {
    try {
      final result = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
      return AuthResult(user: result.user);
    } on FirebaseAuthException catch (e) {
      final ex = AuthException(e.message ?? 'Sign up failed', code: e.code, cause: e);
      ex.log(context: {'email': email});
      return AuthResult(error: ex.userMessage);
    } catch (e) {
      const ex = AuthException('Sign up failed');
      return AuthResult(error: ex.userMessage);
    }
  }

  Future<AuthResult> signInWithGoogle() async {
    if (kIsWeb) {
      return AuthResult(error: 'Use the Google button for web sign-in');
    }
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return AuthResult(error: 'Google sign-in was cancelled');
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final result = await _auth.signInWithCredential(credential);
      return AuthResult(user: result.user);
    } on FirebaseAuthException catch (e) {
      final ex = AuthException(e.message ?? 'Google sign-in failed', code: e.code, cause: e);
      ex.log();
      return AuthResult(error: ex.userMessage);
    } catch (e) {
      const ex = AuthException('Google sign-in failed');
      return AuthResult(error: ex.userMessage);
    }
  }

  Future<AuthResult> signInWithGoogleTokens(
      String accessToken, String idToken) async {
    try {
      final credential = GoogleAuthProvider.credential(
        accessToken: accessToken,
        idToken: idToken,
      );
      final result = await _auth.signInWithCredential(credential);
      return AuthResult(user: result.user);
    } on FirebaseAuthException catch (e) {
      final ex = AuthException(e.message ?? 'Google sign-in failed', code: e.code, cause: e);
      ex.log();
      return AuthResult(error: ex.userMessage);
    } catch (e) {
      const ex = AuthException('Google sign-in failed');
      return AuthResult(error: ex.userMessage);
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
  }
}
