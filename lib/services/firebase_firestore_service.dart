import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/temp_reading.dart';

class FirebaseFirestoreService {
  static final FirebaseFirestoreService _instance = FirebaseFirestoreService._internal();
  factory FirebaseFirestoreService() => _instance;
  FirebaseFirestoreService._internal();

  FirebaseFirestore? _firestore;

  // Lazy-initialize Firestore (only when Firebase is ready)
  FirebaseFirestore? get _firestoreInstance {
    try {
      _firestore ??= FirebaseFirestore.instance;
      return _firestore;
    } catch (e) {
      debugPrint('⚠️  [Firestore] Firebase not initialized yet: $e');
      return null;
    }
  }

  // Collection references
  CollectionReference? get users {
    final firestore = _firestoreInstance;
    return firestore?.collection('users');
  }
  
  CollectionReference? get readings {
    final firestore = _firestoreInstance;
    return firestore?.collection('readings');
  }
  
  CollectionReference? get subscriptions {
    final firestore = _firestoreInstance;
    return firestore?.collection('subscriptions');
  }

  /// Create new user profile
  Future<void> createUserProfile({
    required String userId,
    required String email,
    String? displayName,
    String? photoURL,
  }) async {
    final usersCollection = users;
    if (usersCollection == null) {
      debugPrint('❌ [Firestore] Firebase not initialized');
      return;
    }
    
    try {
      debugPrint('💾 [Firestore] Creating user profile: $userId');
      
      await usersCollection.doc(userId).set({
        'userId': userId,
        'email': email,
        'displayName': displayName,
        'photoURL': photoURL,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ [Firestore] User profile created');
    } catch (e) {
      debugPrint('❌ [Firestore] Create user profile failed: $e');
      rethrow;
    }
  }

  /// Save user profile data
  Future<void> saveUserProfile({
    required String userId,
    required Map<String, dynamic> data,
  }) async {
    final usersCollection = users;
    if (usersCollection == null) {
      debugPrint('❌ [Firestore] Firebase not initialized');
      return;
    }
    
    try {
      debugPrint('💾 [Firestore] Saving user profile: $userId');
      
      await usersCollection.doc(userId).set({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('✅ [Firestore] User profile saved');
    } catch (e) {
      debugPrint('❌ [Firestore] Save user profile failed: $e');
      rethrow;
    }
  }

  /// Get user profile data
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    final usersCollection = users;
    if (usersCollection == null) {
      debugPrint('❌ [Firestore] Firebase not initialized');
      return null;
    }
    
    try {
      debugPrint('📖 [Firestore] Getting user profile: $userId');
      
      final doc = await usersCollection.doc(userId).get();
      
      if (doc.exists) {
        debugPrint('✅ [Firestore] User profile found');
        return doc.data() as Map<String, dynamic>?;
      }
      
      debugPrint('⚠️  [Firestore] User profile not found');
      return null;
    } catch (e) {
      debugPrint('❌ [Firestore] Get user profile failed: $e');
      rethrow;
    }
  }

  /// Save temperature reading to cloud
  Future<void> saveReading({
    required String userId,
    required TempReading reading,
  }) async {
    final readingsCollection = readings;
    if (readingsCollection == null) {
      debugPrint('❌ [Firestore] Firebase not initialized');
      return;
    }
    
    try {
      debugPrint('💾 [Firestore] Saving temperature reading for user: $userId');
      
      await readingsCollection.add({
        'userId': userId,
        'temperature': reading.temperature,
        'rawTemp': reading.rawTemp,
        'timestamp': Timestamp.fromDate(reading.timestamp),
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ [Firestore] Reading saved');
    } catch (e) {
      debugPrint('❌ [Firestore] Save reading failed: $e');
      rethrow;
    }
  }

  /// Get user's temperature readings
  Stream<List<TempReading>> getUserReadings({
    required String userId,
    int limit = 100,
  }) {
    final readingsCollection = readings;
    if (readingsCollection == null) {
      debugPrint('❌ [Firestore] Firebase not initialized');
      return Stream.value([]);
    }
    
    debugPrint('📊 [Firestore] Streaming readings for user: $userId');
    
    return readingsCollection
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return TempReading(
          temperature: (data['temperature'] as num).toDouble(),
          rawTemp: (data['rawTemp'] as num).toDouble(),
          timestamp: (data['timestamp'] as Timestamp).toDate(),
        );
      }).toList();
    });
  }

  /// Save subscription status
  Future<void> saveSubscription({
    required String userId,
    required bool isPremium,
    String? purchaseId,
    String? productId,
    DateTime? expiryDate,
  }) async {
    final subscriptionsCollection = subscriptions;
    if (subscriptionsCollection == null) {
      debugPrint('❌ [Firestore] Firebase not initialized');
      return;
    }
    
    try {
      debugPrint('💾 [Firestore] Saving subscription for user: $userId');
      
      await subscriptionsCollection.doc(userId).set({
        'userId': userId,
        'isPremium': isPremium,
        'purchaseId': purchaseId,
        'productId': productId,
        'expiryDate': expiryDate != null ? Timestamp.fromDate(expiryDate) : null,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('✅ [Firestore] Subscription saved');
    } catch (e) {
      debugPrint('❌ [Firestore] Save subscription failed: $e');
      rethrow;
    }
  }

  /// Get subscription status
  Future<Map<String, dynamic>?> getSubscription(String userId) async {
    final subscriptionsCollection = subscriptions;
    if (subscriptionsCollection == null) {
      debugPrint('❌ [Firestore] Firebase not initialized');
      return null;
    }
    
    try {
      debugPrint('📖 [Firestore] Getting subscription for user: $userId');
      
      final doc = await subscriptionsCollection.doc(userId).get();
      
      if (doc.exists) {
        debugPrint('✅ [Firestore] Subscription found');
        return doc.data() as Map<String, dynamic>?;
      }
      
      debugPrint('⚠️  [Firestore] Subscription not found');
      return null;
    } catch (e) {
      debugPrint('❌ [Firestore] Get subscription failed: $e');
      rethrow;
    }
  }

  /// Stream subscription status
  Stream<Map<String, dynamic>?> streamSubscription(String userId) {
    final subscriptionsCollection = subscriptions;
    if (subscriptionsCollection == null) {
      debugPrint('❌ [Firestore] Firebase not initialized');
      return Stream.value(null);
    }
    
    debugPrint('📊 [Firestore] Streaming subscription for user: $userId');
    
    return subscriptionsCollection.doc(userId).snapshots().map((doc) {
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>?;
      }
      return null;
    });
  }

  /// Delete user data (for account deletion)
  Future<void> deleteUserData(String userId) async {
    final usersCollection = users;
    final readingsCollection = readings;
    final subscriptionsCollection = subscriptions;
    
    if (usersCollection == null || readingsCollection == null || subscriptionsCollection == null) {
      debugPrint('❌ [Firestore] Firebase not initialized');
      return;
    }
    
    try {
      debugPrint('🗑️ [Firestore] Deleting all data for user: $userId');
      
      // Delete user profile
      await usersCollection.doc(userId).delete();
      
      // Delete all readings
      final readingsSnapshot = await readingsCollection
          .where('userId', isEqualTo: userId)
          .get();
      
      for (var doc in readingsSnapshot.docs) {
        await doc.reference.delete();
      }
      
      // Delete subscription
      await subscriptionsCollection.doc(userId).delete();

      debugPrint('✅ [Firestore] User data deleted');
    } catch (e) {
      debugPrint('❌ [Firestore] Delete user data failed: $e');
      rethrow;
    }
  }

  /// Batch save multiple readings (for sync)
  Future<void> batchSaveReadings({
    required String userId,
    required List<TempReading> readingsList,
  }) async {
    final firestore = _firestoreInstance;
    final readingsCollection = readings;
    
    if (firestore == null || readingsCollection == null) {
      debugPrint('❌ [Firestore] Firebase not initialized');
      return;
    }
    
    try {
      debugPrint('💾 [Firestore] Batch saving ${readingsList.length} readings');
      
      final batch = firestore.batch();
      
      for (var reading in readingsList) {
        final docRef = readingsCollection.doc();
        batch.set(docRef, {
          'userId': userId,
          'temperature': reading.temperature,
          'rawTemp': reading.rawTemp,
          'timestamp': Timestamp.fromDate(reading.timestamp),
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      
      await batch.commit();
      debugPrint('✅ [Firestore] Batch save completed');
    } catch (e) {
      debugPrint('❌ [Firestore] Batch save failed: $e');
      rethrow;
    }
  }

  /// Get statistics for user
  Future<Map<String, dynamic>> getUserStats(String userId) async {
    final readingsCollection = readings;
    if (readingsCollection == null) {
      debugPrint('❌ [Firestore] Firebase not initialized');
      return {
        'totalReadings': 0,
        'avgTemp': 0.0,
        'maxTemp': 0.0,
        'minTemp': 0.0,
      };
    }
    
    try {
      debugPrint('📊 [Firestore] Getting stats for user: $userId');
      
      final snapshot = await readingsCollection
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(1000)
          .get();

      if (snapshot.docs.isEmpty) {
        return {
          'totalReadings': 0,
          'avgTemp': 0.0,
          'maxTemp': 0.0,
          'minTemp': 0.0,
        };
      }

      final temps = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return (data['temperature'] as num).toDouble();
      }).toList();

      final avgTemp = temps.reduce((a, b) => a + b) / temps.length;
      final maxTemp = temps.reduce((a, b) => a > b ? a : b);
      final minTemp = temps.reduce((a, b) => a < b ? a : b);

      debugPrint('✅ [Firestore] Stats calculated');
      
      return {
        'totalReadings': snapshot.docs.length,
        'avgTemp': avgTemp,
        'maxTemp': maxTemp,
        'minTemp': minTemp,
      };
    } catch (e) {
      debugPrint('❌ [Firestore] Get stats failed: $e');
      rethrow;
    }
  }
}
