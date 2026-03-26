import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/material.dart';

class FirebaseAuthService {
  static final FirebaseAuthService _instance = FirebaseAuthService._internal();
  factory FirebaseAuthService() => _instance;
  FirebaseAuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Current user stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  
  // Current user
  User? get currentUser => _auth.currentUser;
  
  // Check if user is signed in
  bool get isSignedIn => _auth.currentUser != null;

  /// Sign up with email and password
  Future<UserCredential?> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      debugPrint('🔐 [Auth] Signing up user: $email');
      
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update display name if provided
      if (displayName != null && credential.user != null) {
        await credential.user!.updateDisplayName(displayName);
        await credential.user!.reload();
      }

      debugPrint('✅ [Auth] Sign up successful: ${credential.user?.uid}');
      return credential;
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ [Auth] Sign up failed: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('❌ [Auth] Sign up error (Firebase not initialized?): $e');
      return null;
    }
  }

  /// Sign in with email and password
  Future<UserCredential?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      debugPrint('🔐 [Auth] Signing in user: $email');
      
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      debugPrint('✅ [Auth] Sign in successful: ${credential.user?.uid}');
      return credential;
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ [Auth] Sign in failed: ${e.code} - ${e.message}');
      rethrow;
    }
  }

  /// Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      debugPrint('🔐 [Auth] Starting Google Sign-In');
      
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        debugPrint('⚠️  [Auth] Google Sign-In cancelled by user');
        return null;
      }

      debugPrint('✅ [Auth] Google user selected: ${googleUser.email}');

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final userCredential = await _auth.signInWithCredential(credential);
      
      debugPrint('✅ [Auth] Google Sign-In successful: ${userCredential.user?.uid}');
      return userCredential;
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ [Auth] Google Sign-In failed: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('❌ [Auth] Google Sign-In error: $e');
      rethrow;
    }
  }

  /// Sign in anonymously
  Future<UserCredential?> signInAnonymously() async {
    try {
      debugPrint('🔐 [Auth] Signing in anonymously');
      
      final credential = await _auth.signInAnonymously();

      debugPrint('✅ [Auth] Anonymous sign in successful: ${credential.user?.uid}');
      return credential;
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ [Auth] Anonymous sign in failed: ${e.code} - ${e.message}');
      rethrow;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      debugPrint('🔐 [Auth] Signing out user');
      
      // Sign out from Google if signed in with Google
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
        debugPrint('✅ [Auth] Google Sign-Out successful');
      }
      
      await _auth.signOut();
      debugPrint('✅ [Auth] Sign out successful');
    } catch (e) {
      debugPrint('❌ [Auth] Sign out failed: $e');
      rethrow;
    }
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      debugPrint('📧 [Auth] Sending password reset email to: $email');
      await _auth.sendPasswordResetEmail(email: email);
      debugPrint('✅ [Auth] Password reset email sent');
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ [Auth] Password reset failed: ${e.code} - ${e.message}');
      rethrow;
    }
  }

  /// Delete current user account
  Future<void> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No user signed in');
      }

      debugPrint('🗑️ [Auth] Deleting user account: ${user.uid}');
      await user.delete();
      debugPrint('✅ [Auth] Account deleted successfully');
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ [Auth] Account deletion failed: ${e.code} - ${e.message}');
      rethrow;
    }
  }

  /// Update user profile
  Future<void> updateProfile({
    String? displayName,
    String? photoURL,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No user signed in');
      }

      debugPrint('👤 [Auth] Updating user profile');
      
      if (displayName != null) {
        await user.updateDisplayName(displayName);
      }
      
      if (photoURL != null) {
        await user.updatePhotoURL(photoURL);
      }
      
      await user.reload();
      debugPrint('✅ [Auth] Profile updated successfully');
    } catch (e) {
      debugPrint('❌ [Auth] Profile update failed: $e');
      rethrow;
    }
  }

  /// Get error message from FirebaseAuthException
  String getErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'The password is too weak.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'invalid-email':
        return 'The email address is invalid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled.';
      case 'requires-recent-login':
        return 'Please sign in again to complete this action.';
      default:
        return e.message ?? 'An error occurred. Please try again.';
    }
  }
}
