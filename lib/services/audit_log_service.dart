import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'platform_compat.dart';
import '../models/user_model.dart';

/// Writes to the shared `auditLogs` collection (same one the web Software
/// Control → Audit Logs tab reads) so logins, logouts and data changes from
/// mobile appear alongside web activity, with the device used.
class AuditLogService {
  static String _platform = 'unknown';
  static String _device = '';
  static bool _deviceResolved = false;

  static Future<void> _resolveDevice() async {
    if (_deviceResolved) return;
    _deviceResolved = true;
    try {
      final info = DeviceInfoPlugin();
      if (kIsWeb) {
        final w = await info.webBrowserInfo;
        _platform = 'web';
        _device = '${w.browserName.name} · ${w.appVersion ?? ''}';
      } else if (PlatformCompat.isAndroid) {
        final a = await info.androidInfo;
        _platform = 'android';
        _device = '${a.manufacturer} ${a.model} · Android ${a.version.release}';
      } else if (PlatformCompat.isIOS) {
        final i = await info.iosInfo;
        _platform = 'ios';
        _device = '${i.utsname.machine} · ${i.systemName} ${i.systemVersion}';
      }
    } catch (_) {}
  }

  /// action: login | logout | create | update | delete
  static Future<void> log({
    required UserModel user,
    required String action,
    String? targetType,
    String? targetId,
    String? description,
  }) async {
    try {
      await _resolveDevice();
      await FirebaseFirestore.instance.collection('auditLogs').add({
        'userId': user.id,
        'userName': user.fullNameEnglish ?? user.fullName ?? user.username,
        'userEmail': user.email,
        'hierarchyLevel': user.hierarchyLevel,
        'action': action,
        'targetType': targetType,
        'targetId': targetId,
        'description': description,
        'platform': _platform,
        'device': _device,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (kDebugMode) print('[AuditLogService] log failed: $e');
    }
  }

  /// Convenience wrapper for data mutations, mirroring the web's
  /// `auditLogService.dataChange(action, targetType, targetId, description)`.
  ///
  /// Reads the signed-in user from AuthService when one is available; when no
  /// user is signed in (or the actor cannot be resolved) the write is skipped —
  /// auditing must never break the user's action, and the web rules only
  /// accept entries carrying a real actor anyway.
  static Future<void> dataChange({
    required String action,
    required String targetType,
    String? targetId,
    String? description,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final profile = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (!profile.exists) return;
      final model = UserModel.fromFirestore(
        user.uid,
        profile.data() ?? const {},
        user.email ?? '',
      );
      await log(
        user: model,
        action: action,
        targetType: targetType,
        targetId: targetId,
        description: description,
      );
    } catch (e) {
      if (kDebugMode) print('[AuditLogService] dataChange skipped: $e');
    }
  }
}
