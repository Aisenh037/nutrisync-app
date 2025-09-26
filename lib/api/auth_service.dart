import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// A result class for authentication actions, containing either a user or an error message.
class AuthResult {
  final User? user;
  final String? error;
  AuthResult({this.user, this.error});
}

/// Service for handling authentication with Firebase Auth.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

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

  /// Sign in with Google for non-web platforms.
  /// Returns [AuthResult] with user or error message.
  Future<AuthResult> signInWithGoogle() async {
    if (kIsWeb) {
      return AuthResult(error: 'Use the Google button for web sign-in');
    }
    try {
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        return AuthResult(error: 'Google sign in was cancelled');
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Once signed in, return the UserCredential
      final result = await _auth.signInWithCredential(credential);
      return AuthResult(user: result.user);
    } on FirebaseAuthException catch (e) {
      return AuthResult(error: e.message ?? 'Google sign in failed');
    } catch (e) {
      return AuthResult(error: 'Google sign in failed: $e');
    }
  }

  /// Sign in with Google tokens for web platform.
  /// This is called from the web button callback with accessToken and idToken.
  Future<AuthResult> signInWithGoogleTokens(String accessToken, String idToken) async {
    try {
      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: accessToken,
        idToken: idToken,
      );

      // Once signed in, return the UserCredential
      final result = await _auth.signInWithCredential(credential);
      return AuthResult(user: result.user);
    } on FirebaseAuthException catch (e) {
      return AuthResult(error: e.message ?? 'Google sign in failed');
    } catch (e) {
      return AuthResult(error: 'Google sign in failed: $e');
    }
  }

  /// Sign out the current user.
  Future<void> signOut() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
  }
}
