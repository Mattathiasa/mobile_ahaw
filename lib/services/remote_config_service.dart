import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Live remote configuration controlled from the web admin
/// (Settings → Mobile App Control → siteConfig/mobileAppConfig).
///
/// Provides:
///  - kill switch + maintenance message
///  - forced update when this build is older than [minBuildNumber]
///  - per-module feature flags (missing key = enabled)
class RemoteConfigService extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;

  bool killSwitch = false;
  String maintenanceMessage =
      'The app is under maintenance. Please try again later.';
  int minBuildNumber = 1;
  String latestVersionName = '';
  String updateUrl = '';
  Map<String, dynamic> features = {};

  String appVersion = '';
  int buildNumber = 0;

  bool get forceUpdate => buildNumber > 0 && buildNumber < minBuildNumber;

  RemoteConfigService() {
    _init();
  }

  Future<void> _init() async {
    try {
      final info = await PackageInfo.fromPlatform();
      appVersion = info.version;
      buildNumber = int.tryParse(info.buildNumber) ?? 0;
    } catch (e) {
      if (kDebugMode) print('[RemoteConfig] package info failed: $e');
    }

    _sub = _db
        .collection('siteConfig')
        .doc('mobileAppConfig')
        .snapshots()
        .listen((snap) {
      final data = snap.data();
      if (data == null) return;
      killSwitch = data['killSwitch'] == true;
      maintenanceMessage =
          (data['maintenanceMessage'] as String?) ?? maintenanceMessage;
      minBuildNumber = (data['minBuildNumber'] as num?)?.toInt() ?? 1;
      latestVersionName = (data['latestVersionName'] as String?) ?? '';
      updateUrl = (data['updateUrl'] as String?) ?? '';
      features = (data['features'] as Map<String, dynamic>?) ?? {};
      notifyListeners();
    }, onError: (e) {
      if (kDebugMode) print('[RemoteConfig] listen failed: $e');
    });
  }

  /// A module is enabled unless the admin explicitly switched it off.
  bool isEnabled(String featureKey) => features[featureKey] != false;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
