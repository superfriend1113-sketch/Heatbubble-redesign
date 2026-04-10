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
      return;
    }
    
    try {
      
      await usersCollection.doc(userId).set({
        'userId': userId,
        'email': email,
        'displayName': displayName,
        'photoURL': photoURL,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

    } catch (e) {
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
      return;
    }
    
    try {
      
      await usersCollection.doc(userId).set({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

    } catch (e) {
      rethrow;
    }
  }

  /// Get user profile data
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    final usersCollection = users;
    if (usersCollection == null) {
      return null;
    }
    
    try {
      
      final doc = await usersCollection.doc(userId).get();
      
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>?;
      }
      
      return null;
    } catch (e) {
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
      return;
    }
    
    try {
      
      await readingsCollection.add({
        'userId': userId,
        'temperature': reading.temperature,
        'rawTemp': reading.rawTemp,
        'timestamp': Timestamp.fromDate(reading.timestamp),
        'createdAt': FieldValue.serverTimestamp(),
      });

    } catch (e) {
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
      return Stream.value([]);
    }
    
    
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
    String? purchaseToken,
  }) async {
    final subscriptionsCollection = subscriptions;
    if (subscriptionsCollection == null) {
      return;
    }
    
    try {
      
      await subscriptionsCollection.doc(userId).set({
        'userId': userId,
        'isPremium': isPremium,
        'purchaseId': purchaseId,
        'productId': productId,
        'purchaseToken': purchaseToken,
        'expiryDate': expiryDate != null ? Timestamp.fromDate(expiryDate) : null,
        'status': isPremium ? 'active' : 'inactive',
        'autoRenewing': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

    } catch (e) {
      rethrow;
    }
  }

  /// Get subscription status
  Future<Map<String, dynamic>?> getSubscription(String userId) async {
    final subscriptionsCollection = subscriptions;
    if (subscriptionsCollection == null) {
      return null;
    }
    
    try {
      
      final doc = await subscriptionsCollection.doc(userId).get();
      
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>?;
      }
      
      return null;
    } catch (e) {
      rethrow;
    }
  }

  /// Stream subscription status
  Stream<Map<String, dynamic>?> streamSubscription(String userId) {
    final subscriptionsCollection = subscriptions;
    if (subscriptionsCollection == null) {
      return Stream.value(null);
    }
    
    
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
      return;
    }
    
    try {
      
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

    } catch (e) {
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
      return;
    }
    
    try {
      
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
    } catch (e) {
      rethrow;
    }
  }

  /// Get statistics for user
  Future<Map<String, dynamic>> getUserStats(String userId) async {
    final readingsCollection = readings;
    if (readingsCollection == null) {
      return {
        'totalReadings': 0,
        'avgTemp': 0.0,
        'maxTemp': 0.0,
        'minTemp': 0.0,
      };
    }
    
    try {
      
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

      
      return {
        'totalReadings': snapshot.docs.length,
        'avgTemp': avgTemp,
        'maxTemp': maxTemp,
        'minTemp': minTemp,
      };
    } catch (e) {
      rethrow;
    }
  }
}
