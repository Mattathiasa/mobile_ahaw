import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Consumes the web's per-module configuration (`siteConfig/moduleConfig`),
/// mirroring src/services/moduleConfig.ts. The mobile app READS it — editing
/// stays on the web (Module Config) per the operational-first scope.
///
/// Provides field show/hide, admin label overrides, and the named option lists
/// used by module dropdowns (with the same built-in defaults as web, so forms
/// work before an admin edits anything).
class ModuleConfigService extends ChangeNotifier {
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;
  Map<String, dynamic> _config = {};

  /// Built-in option lists (from DEFAULT_MODULE_CONFIG in moduleConfig.ts). Used
  /// when the admin has not overridden a module's option list.
  static const Map<String, Map<String, List<String>>> _defaultOptions = {
    'members': {
      'genders': ['Male', 'Female'],
      'sortBy': ['name', 'hierarchy', 'region', 'zone'],
    },
    'plans': {
      'periods': ['Weekly', 'Monthly', 'Annually'],
      'departments': [
        'Evangelism',
        'Education & Training',
        'Services Coordination',
        'Administration & Finance',
        'Public & External Relations',
        'Youth & Children',
      ],
    },
    'reports': {
      'types': ['Memriya', 'Kifil', 'Zerf'],
      'departments': [
        'Evangelism',
        'Education & Training',
        'Services Coordination',
        'Administration & Finance',
        'Public & External Relations',
        'Youth & Children',
      ],
    },
    'finance': {
      'transactionTypes': [
        'Income', 'Expense', 'Tithe', 'Offering', 'Donation',
        'Collection', 'Deposit', 'Asrat', 'YefikirSetota', 'Transfer',
      ],
      'bankAccounts': [
        'CBE', 'Berhan Bank', 'Abyssinia Bank', 'Awash Bank',
        'Oromia Bank', 'Nib Bank',
      ],
    },
    'hr': {
      'employmentTypes': ['FullTime', 'PartTime', 'Contract', 'Volunteer'],
      'statuses': ['Active', 'OnLeave', 'Terminated'],
    },
    'inventory': {
      'conditions': ['New', 'Good', 'Fair', 'Poor'],
      'statuses': ['InUse', 'InStorage', 'Maintenance', 'Retired'],
    },
    'teachings': {
      'serviceTypes': [
        'Sunday Morning', 'Wednesday Bible Study', "Men's Breakfast",
        "Women's Ministry", 'Youth Service', 'Special Event', 'Other',
      ],
    },
    'missionary': {
      'missionaryTypes': ['FullTime', 'PartTime', 'ShortTerm'],
    },
    'volunteer': {
      'ministries': [
        'Ebet Metreg', 'Natanim Agelgelot', 'Choir', 'Ushering',
        'Sunday School', 'Charity', 'Evangelism', 'Media',
      ],
    },
  };

  ModuleConfigService() {
    _sub = FirebaseFirestore.instance
        .collection('siteConfig')
        .doc('moduleConfig')
        .snapshots()
        .listen((snap) {
      _config = snap.data() ?? {};
      notifyListeners();
    }, onError: (e) {
      if (kDebugMode) print('[ModuleConfig] listen failed: $e');
    });
  }

  Map<String, dynamic>? _module(String moduleKey) {
    final m = _config[moduleKey];
    return m is Map<String, dynamic> ? m : null;
  }

  List<Map<String, dynamic>> _fields(String moduleKey) {
    final f = _module(moduleKey)?['fields'];
    if (f is List) return f.whereType<Map<String, dynamic>>().toList();
    return const [];
  }

  Map<String, dynamic>? _field(String moduleKey, String fieldKey) {
    for (final f in _fields(moduleKey)) {
      if (f['key'] == fieldKey) return f;
    }
    return null;
  }

  /// Whether a field is shown. Defaults to true when the admin hasn't set it.
  bool isVisible(String moduleKey, String fieldKey) {
    final f = _field(moduleKey, fieldKey);
    if (f == null) return true;
    return f['visible'] != false;
  }

  /// Whether a field is required. Defaults to false when unset.
  bool isRequired(String moduleKey, String fieldKey) {
    final f = _field(moduleKey, fieldKey);
    return f != null && f['required'] == true;
  }

  /// An admin's label override for a field, or null to use the app's own label.
  String? labelOverride(String moduleKey, String fieldKey) {
    final label = _field(moduleKey, fieldKey)?['label'];
    if (label is String && label.trim().isNotEmpty) return label;
    return null;
  }

  String headerTitle(String moduleKey) {
    final v = _module(moduleKey)?['headerTitle'];
    return (v is String) ? v : '';
  }

  String headerDescription(String moduleKey) {
    final v = _module(moduleKey)?['headerDescription'];
    return (v is String) ? v : '';
  }

  String learnMore(String moduleKey) {
    final v = _module(moduleKey)?['learnMore'];
    return (v is String) ? v : '';
  }

  /// A module's named option list — the admin override if present, else the
  /// built-in default, else an empty list.
  List<String> options(String moduleKey, String optionName) {
    final opts = _module(moduleKey)?['options'];
    if (opts is Map) {
      final list = opts[optionName];
      if (list is List && list.isNotEmpty) {
        return list.map((e) => e.toString()).toList();
      }
    }
    return _defaultOptions[moduleKey]?[optionName] ?? const [];
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
