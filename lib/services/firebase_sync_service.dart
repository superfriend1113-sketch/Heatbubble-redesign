import 'package:flutter/material.dart';
import 'firebase_auth_service.dart';
import 'firebase_firestore_service.dart';
import 'storage_service.dart';
import 'subscription_service.dart';

class FirebaseSyncService {
  static final FirebaseSyncService _instance = FirebaseSyncService._internal();
  factory FirebaseSyncService() => _instance;
  FirebaseSyncService._internal();

  final _auth = FirebaseAuthService();
  final _firestore = FirebaseFirestoreService();
  final _storage = StorageService();
  final _subscription = SubscriptionService();

  bool _isSyncing = false;
  DateTime? _lastSyncTime;

  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncTime => _lastSyncTime;

  /// Sync all local data to Firebase
  Future<void> syncToCloud() async {
    if (!_auth.isSignedIn) {
      return;
    }

    if (_isSyncing) {
      return;
    }

    _isSyncing = true;

    try {
      final userId = _auth.currentUser!.uid;

      // 1. Sync temperature readings
      await _syncReadings(userId);

      // 2. Sync subscription status
      await _syncSubscription(userId);

      // 3. Sync user preferences
      await _syncUserPreferences(userId);

      _lastSyncTime = DateTime.now();
    } catch (e, stackTrace) {
      rethrow;
    } finally {
      _isSyncing = false;
    }
  }

  /// Sync temperature readings to Firestore
  Future<void> _syncReadings(String userId) async {
    try {

      // Get all local readings
      final localReadings = await _storage.getLast7Days();

      if (localReadings.isEmpty) {
        return;
      }

      // Batch upload to Firestore
      await _firestore.batchSaveReadings(
        userId: userId,
        readingsList: localReadings,
      );

    } catch (e) {
      rethrow;
    }
  }

  /// Sync subscription status to Firestore
  Future<void> _syncSubscription(String userId) async {
    try {

      await _firestore.saveSubscription(
        userId: userId,
        isPremium: _subscription.isPremium,
      );

    } catch (e) {
      rethrow;
    }
  }

  /// Sync user preferences to Firestore
  Future<void> _syncUserPreferences(String userId) async {
    try {

      // Get user preferences (unit, notifications, etc.)
      // TODO: Implement preference storage

      await _firestore.saveUserProfile(
        userId: userId,
        data: {
          'lastSyncAt': DateTime.now().toIso8601String(),
          // Add more preferences here
        },
      );

    } catch (e) {
      rethrow;
    }
  }

  /// Restore data from Firebase to local storage
  Future<void> restoreFromCloud() async {
    if (!_auth.isSignedIn) {
      return;
    }


    try {
      final userId = _auth.currentUser!.uid;

      // 1. Restore subscription status
      await _subscription.syncFromFirebase();

      // 2. Restore user preferences
      final profile = await _firestore.getUserProfile(userId);
      if (profile != null) {
        // TODO: Apply preferences to local storage
      }

      // 3. Get cloud statistics
      final stats = await _firestore.getUserStats(userId);

    } catch (e, stackTrace) {
      rethrow;
    }
  }

  /// Auto-sync on app start (if user is signed in)
  Future<void> autoSync() async {
    if (!_auth.isSignedIn) {
      return;
    }

    // Check if last sync was more than 1 hour ago
    if (_lastSyncTime != null) {
      final hoursSinceLastSync = DateTime.now().difference(_lastSyncTime!).inHours;
      if (hoursSinceLastSync < 1) {
        return;
      }
    }

    try {
      await syncToCloud();
    } catch (e) {
      // Don't throw - auto-sync failures shouldn't block app
    }
  }

  /// Clear all cloud data (for account deletion)
  Future<void> clearCloudData() async {
    if (!_auth.isSignedIn) {
      return;
    }


    try {
      final userId = _auth.currentUser!.uid;

      // Delete Firestore data
      await _firestore.deleteUserData(userId);

      // Delete Storage files
      // await _storageService.deleteUserFiles(userId);

    } catch (e) {
      rethrow;
    }
  }
}
