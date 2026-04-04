import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

class FirebaseStorageService {
  static final FirebaseStorageService _instance = FirebaseStorageService._internal();
  factory FirebaseStorageService() => _instance;
  FirebaseStorageService._internal();

  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Upload user profile picture
  Future<String> uploadProfilePicture({
    required String userId,
    required File imageFile,
  }) async {
    try {
      
      final ref = _storage.ref().child('users/$userId/profile.jpg');
      
      final uploadTask = ref.putFile(
        imageFile,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {'userId': userId},
        ),
      );

      // Monitor upload progress
      uploadTask.snapshotEvents.listen((snapshot) {
        final progress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
      });

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      rethrow;
    }
  }

  /// Upload temperature chart/graph image
  Future<String> uploadChartImage({
    required String userId,
    required File imageFile,
    required String chartId,
  }) async {
    try {
      
      final ref = _storage.ref().child('users/$userId/charts/$chartId.png');
      
      final uploadTask = ref.putFile(
        imageFile,
        SettableMetadata(
          contentType: 'image/png',
          customMetadata: {
            'userId': userId,
            'chartId': chartId,
          },
        ),
      );

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      rethrow;
    }
  }

  /// Upload exported data file (CSV, JSON, etc.)
  Future<String> uploadExportedData({
    required String userId,
    required File dataFile,
    required String fileName,
  }) async {
    try {
      
      final ref = _storage.ref().child('users/$userId/exports/$fileName');
      
      final uploadTask = ref.putFile(dataFile);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      rethrow;
    }
  }

  /// Delete file from storage
  Future<void> deleteFile(String filePath) async {
    try {
      
      final ref = _storage.ref().child(filePath);
      await ref.delete();

    } catch (e) {
      rethrow;
    }
  }

  /// Delete all user files
  Future<void> deleteUserFiles(String userId) async {
    try {
      
      final ref = _storage.ref().child('users/$userId');
      final listResult = await ref.listAll();

      // Delete all files
      for (var item in listResult.items) {
        await item.delete();
      }

      // Recursively delete subdirectories
      for (var prefix in listResult.prefixes) {
        await _deleteDirectory(prefix);
      }

    } catch (e) {
      rethrow;
    }
  }

  /// Helper to recursively delete directory
  Future<void> _deleteDirectory(Reference ref) async {
    final listResult = await ref.listAll();
    
    for (var item in listResult.items) {
      await item.delete();
    }
    
    for (var prefix in listResult.prefixes) {
      await _deleteDirectory(prefix);
    }
  }

  /// Get download URL for a file
  Future<String> getDownloadUrl(String filePath) async {
    try {
      
      final ref = _storage.ref().child(filePath);
      final url = await ref.getDownloadURL();

      return url;
    } catch (e) {
      rethrow;
    }
  }

  /// List all files in a directory
  Future<List<String>> listFiles(String directoryPath) async {
    try {
      
      final ref = _storage.ref().child(directoryPath);
      final listResult = await ref.listAll();

      final fileNames = listResult.items.map((item) => item.name).toList();

      return fileNames;
    } catch (e) {
      rethrow;
    }
  }

  /// Get file metadata
  Future<FullMetadata> getFileMetadata(String filePath) async {
    try {
      
      final ref = _storage.ref().child(filePath);
      final metadata = await ref.getMetadata();

      return metadata;
    } catch (e) {
      rethrow;
    }
  }
}
