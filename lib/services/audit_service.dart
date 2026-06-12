import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../models/user_model.dart';

/// Reports this device/user session to `mobileAudit/{uid}` so admins can
/// audit installed versions and activity from the web app
/// (Settings → Mobile App Control → Device Audit).
class AuditService {
  static bool _reportedThisLaunch = false;

  /// Upserts the audit record. Safe to call repeatedly; it only writes once
  /// per app launch.
  static Future<void> report(UserModel user) async {
    if (_reportedThisLaunch) return;
    _reportedThisLaunch = true;

    try {
      final db = FirebaseFirestore.instance;
      final ref = db.collection('mobileAudit').doc(user.id);

      String platform = 'unknown';
      String deviceModel = '';
      String osVersion = '';
      try {
        final deviceInfo = DeviceInfoPlugin();
        if (Platform.isAndroid) {
          final android = await deviceInfo.androidInfo;
          platform = 'android';
          deviceModel = '${android.manufacturer} ${android.model}';
          osVersion = 'Android ${android.version.release}';
        } else if (Platform.isIOS) {
          final ios = await deviceInfo.iosInfo;
          platform = 'ios';
          deviceModel = ios.utsname.machine;
          osVersion = '${ios.systemName} ${ios.systemVersion}';
        }
      } catch (_) {}

      String appVersion = '';
      int buildNumber = 0;
      try {
        final info = await PackageInfo.fromPlatform();
        appVersion = info.version;
        buildNumber = int.tryParse(info.buildNumber) ?? 0;
      } catch (_) {}

      final now = DateTime.now().toUtc().toIso8601String();
      final existing = await ref.get();

      await ref.set({
        'displayName': user.fullNameEnglish ?? user.fullName ?? user.username,
        'email': user.email,
        'hierarchyLevel': user.hierarchyLevel,
        'platform': platform,
        'appVersion': appVersion,
        'buildNumber': buildNumber,
        'deviceModel': deviceModel,
        'osVersion': osVersion,
        'lastSeen': now,
        if (!existing.exists) 'firstSeen': now,
        'sessionCount': FieldValue.increment(1),
      }, SetOptions(merge: true));
    } catch (e) {
      // Auditing must never break the app.
      if (kDebugMode) print('[AuditService] report failed: $e');
    }
  }
}
