import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';

/// Handles in-app updates from Google Play
class AppUpdateService {
  static final AppUpdateService _instance = AppUpdateService._internal();
  factory AppUpdateService() => _instance;
  AppUpdateService._internal();

  bool _isChecking = false;
  DateTime? _lastCheckTime;

  /// Check for updates and prompt user if available
  /// Call this on app start or resume
  Future<void> checkForUpdate({
    bool forceImmediate = false,
  }) async {
    // Prevent multiple simultaneous checks
    if (_isChecking) return;

    // Rate limit: Check at most once per hour
    if (_lastCheckTime != null) {
      final hoursSinceLastCheck = DateTime.now().difference(_lastCheckTime!).inHours;
      if (hoursSinceLastCheck < 1) {
        return;
      }
    }

    _isChecking = true;
    _lastCheckTime = DateTime.now();

    try {
      final info = await InAppUpdate.checkForUpdate();

      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        
        if (forceImmediate) {
          // Force immediate update (for critical fixes)
          await _performImmediateUpdate();
        } else {
          // Flexible update (recommended for normal updates)
          await _performFlexibleUpdate();
        }
      } else {
      }
    } catch (e) {
      // Update check failed - don't block app
    } finally {
      _isChecking = false;
    }
  }

  /// Immediate update - blocks app until updated
  /// Use for critical security fixes or breaking changes
  Future<void> _performImmediateUpdate() async {
    try {
      await InAppUpdate.performImmediateUpdate();
    } catch (e) {
      // User cancelled or update failed
    }
  }

  /// Flexible update - downloads in background, installs on next restart
  /// Recommended for normal updates
  Future<void> _performFlexibleUpdate() async {
    try {
      await InAppUpdate.startFlexibleUpdate();
      
      // Listen for download completion
      InAppUpdate.completeFlexibleUpdate().then((_) {
        // Update downloaded, will install on next app restart
      }).catchError((e) {
        // Update failed or cancelled
      });
    } catch (e) {
      // Update failed
    }
  }

  /// Force check for critical updates (call from settings or on critical bug fix)
  Future<bool> checkForCriticalUpdate() async {
    try {
      final info = await InAppUpdate.checkForUpdate();
      
      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        // Check if update is high priority (set in Play Console)
        if (info.updatePriority >= 4) {
          // High priority update - force immediate
          await _performImmediateUpdate();
          return true;
        } else {
          // Normal priority - flexible update
          await _performFlexibleUpdate();
          return true;
        }
      }
      
      return false;
    } catch (e) {
      return false;
    }
  }
}
