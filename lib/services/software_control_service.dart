import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Consumes the web's Software Control config (`siteConfig/softwareControl`),
/// mirroring src/services/softwareControl.ts. The mobile app READS it — editing
/// stays on the web per operational-first scope.
///
/// Gates sidebar entries (nav) and action buttons (elements) by hierarchy
/// level, so hiding a tab/button on the web hides it in the app too. Missing
/// key = visible to all; super admins always see everything.
class SoftwareControlService extends ChangeNotifier {
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;

  Map<String, List<String>> _navAccess = {};
  Map<String, Map<String, dynamic>> _elements = {};

  SoftwareControlService() {
    _sub = FirebaseFirestore.instance
        .collection('siteConfig')
        .doc('softwareControl')
        .snapshots()
        .listen((snap) {
      final data = snap.data() ?? {};
      final nav = data['navAccess'];
      final els = data['elements'];
      _navAccess = {};
      if (nav is Map) {
        nav.forEach((k, v) {
          if (v is List) _navAccess[k.toString()] = v.map((e) => e.toString()).toList();
        });
      }
      _elements = {};
      if (els is Map) {
        els.forEach((k, v) {
          if (v is Map) _elements[k.toString()] = Map<String, dynamic>.from(v);
        });
      }
      notifyListeners();
    }, onError: (e) {
      if (kDebugMode) print('[SoftwareControl] listen failed: $e');
    });
  }

  /// Whether a sidebar entry is visible to [level]. Mirrors navAllowed().
  bool navAllowed(String navKey, String level, bool isSuperAdmin) {
    if (isSuperAdmin) return true;
    final allowed = _navAccess[navKey];
    if (allowed == null || allowed.isEmpty) return true;
    return allowed.contains(level);
  }

  /// Whether an action button is visible to [level]. Mirrors elementAllowed().
  bool elementAllowed(String elementKey, String level, bool isSuperAdmin) {
    if (isSuperAdmin) return true;
    final rule = _elements[elementKey];
    if (rule == null) return true;
    if (rule['visible'] == false) return false;
    final levels = rule['levels'];
    if (levels is List && levels.isNotEmpty) {
      return levels.map((e) => e.toString()).contains(level);
    }
    return true;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
