import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/material.dart';

class FirebaseAuthService {
  static final FirebaseAuthService _instance = FirebaseAuthService._internal();
  factory FirebaseAuthService() => _instance;
  FirebaseAuthService._internal();

  FirebaseAuth? _auth;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Lazy-initialize Firebase Auth (only when Firebase is ready)
  FirebaseAuth? get _authInstance {
    try {
      _auth ??= FirebaseAuth.instance;
      return _auth;
    } catch (e) {
      return null;
    }
  }

  // Current user stream
  Stream<User?> get authStateChanges {
    final auth = _authInstance;
    if (auth == null) return Stream.value(null);
    return auth.authStateChanges();
  }
  
  // Current user
  User? get currentUser {
    final auth = _authInstance;
    return auth?.currentUser;
  }
  
  // Check if user is signed in
  bool get isSignedIn {
    final auth = _authInstance;
    return auth?.currentUser != null;
  }

  /// Sign up with email and password
  Future<UserCredential?> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final auth = _authInstance;
    if (auth == null) {
      return null;
    }
    
    try {
      
      final credential = await auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update display name if provided
      if (displayName != null && credential.user != null) {
        await credential.user!.updateDisplayName(displayName);
        await credential.user!.reload();
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      rethrow;
    } catch (e) {
      return null;
    }
  }

  /// Sign in with email and password
  Future<UserCredential?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final auth = _authInstance;
    if (auth == null) {
      return null;
    }
    
    try {
      
      final credential = await auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      return credential;
    } on FirebaseAuthException catch (e) {
      rethrow;
    }
  }

  /// Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    final auth = _authInstance;
    if (auth == null) {
      return null;
    }
    
    try {
      
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        return null;
      }


      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final userCredential = await auth.signInWithCredential(credential);
      
      return userCredential;
    } on FirebaseAuthException catch (e) {
      rethrow;
    } catch (e) {
      rethrow;
    }
  }

  /// Sign in anonymously
  Future<UserCredential?> signInAnonymously() async {
    final auth = _authInstance;
    if (auth == null) {
      return null;
    }
    
    try {
      
      final credential = await auth.signInAnonymously();

      return credential;
    } on FirebaseAuthException catch (e) {
      rethrow;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    final auth = _authInstance;
    if (auth == null) {
      return;
    }
    
    try {
      
      // Sign out from Google if signed in with Google
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
      }
      
      await auth.signOut();
    } catch (e) {
      rethrow;
    }
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    final auth = _authInstance;
    if (auth == null) {
      return;
    }
    
    try {
      await auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      rethrow;
    }
  }

  /// Delete current user account
  Future<void> deleteAccount() async {
    final auth = _authInstance;
    if (auth == null) {
      return;
    }
    
    try {
      final user = auth.currentUser;
      if (user == null) {
        throw Exception('No user signed in');
      }

      await user.delete();
    } on FirebaseAuthException catch (e) {
      rethrow;
    }
  }

  /// Update user profile
  Future<void> updateProfile({
    String? displayName,
    String? photoURL,
  }) async {
    final auth = _authInstance;
    if (auth == null) {
      return;
    }
    
    try {
      final user = auth.currentUser;
      if (user == null) {
        throw Exception('No user signed in');
      }

      
      if (displayName != null) {
        await user.updateDisplayName(displayName);
      }
      
      if (photoURL != null) {
        await user.updatePhotoURL(photoURL);
      }
      
      await user.reload();
    } catch (e) {
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
