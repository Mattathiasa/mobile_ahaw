import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'role_permissions.dart';

/// Mirrors the web's PermissionContext + permissionService.
/// Fetches role overrides and per-user overrides from Firestore
/// `siteConfig/rolePermissions` and `siteConfig/userPermissionOverrides`.
class PermissionService extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Resolved permission set for the current user
  Set<String> _permissions = {};
  bool _isSuperAdmin = false;
  bool _isLoading = false; // Start false — show defaults immediately

  // Raw overrides (cached)
  Map<String, List<String>> _roleOverrides = {};
  Map<String, Map<String, bool>> _userOverrides = {};
  List<String> _superAdminUids = [];

  // ── Public getters ──────────────────────────────────────────────────────────

  bool get isLoading => _isLoading;
  bool get isSuperAdmin => _isSuperAdmin;

  /// Check if the current user has a specific permission key.
  bool can(String permission) {
    if (_isSuperAdmin) return true;
    return _permissions.contains(permission);
  }

  /// Dashboard view level — mirrors useRolePermissions dashboardView
  String get dashboardView {
    if (can('canViewFullDashboard')) return 'full';
    if (can('canViewLimitedDashboard')) return 'limited';
    return 'basic';
  }

  // ── Load permissions for a user ─────────────────────────────────────────────

  Future<void> loadForUser({
    required String userId,
    required String hierarchyLevel,
    required String role,
  }) async {
    // ── Step 1: Apply defaults immediately so the UI is usable right away ──
    _isSuperAdmin = role == 'SuperAdmin';
    if (_isSuperAdmin) {
      _permissions = Set<String>.from(allPermissions);
    } else {
      _permissions = resolvePermissions(
        hierarchyLevel: hierarchyLevel,
        userId: userId,
        roleOverrides: _roleOverrides, // empty on first load — uses defaults
        userOverrides: _userOverrides,
      );
    }
    _isLoading = false;
    notifyListeners(); // Drawer renders immediately with correct defaults

    // ── Step 2: Fetch Firestore overrides in background ──
    try {
      await Future.wait([
        _fetchRoleOverrides(),
        _fetchUserOverrides(),
        _fetchSuperAdmins(),
      ]);
    } catch (e) {
      if (kDebugMode) {
        print('[PermissionService] Failed to load overrides, using defaults: $e');
      }
    }

    // ── Step 3: Re-resolve with actual Firestore data ──
    _isSuperAdmin = role == 'SuperAdmin' || _superAdminUids.contains(userId);
    if (_isSuperAdmin) {
      _permissions = Set<String>.from(allPermissions);
    } else {
      _permissions = resolvePermissions(
        hierarchyLevel: hierarchyLevel,
        userId: userId,
        roleOverrides: _roleOverrides,
        userOverrides: _userOverrides,
      );
    }
    notifyListeners(); // Update drawer if overrides changed anything
  }

  /// Call this on sign-out to clear permissions
  void clear() {
    _permissions = {};
    _isSuperAdmin = false;
    _isLoading = false;
    _roleOverrides = {};
    _userOverrides = {};
    _superAdminUids = [];
    notifyListeners();
  }

  // ── Firestore fetchers ──────────────────────────────────────────────────────

  Future<void> _fetchRoleOverrides() async {
    try {
      final snap =
          await _db.collection('siteConfig').doc('rolePermissions').get();
      if (snap.exists && snap.data() != null) {
        final data = snap.data()!;
        final result = <String, List<String>>{};
        for (final entry in data.entries) {
          if (entry.key == '_meta') continue;
          if (entry.value is List) {
            result[entry.key] = List<String>.from(entry.value as List);
          }
        }
        _roleOverrides = result;
      }
    } catch (e) {
      if (kDebugMode) print('[PermissionService] roleOverrides fetch error: $e');
    }
  }

  Future<void> _fetchUserOverrides() async {
    try {
      final snap = await _db
          .collection('siteConfig')
          .doc('userPermissionOverrides')
          .get();
      if (snap.exists && snap.data() != null) {
        final data = snap.data()!;
        final result = <String, Map<String, bool>>{};
        for (final entry in data.entries) {
          if (entry.key == '_meta') continue;
          if (entry.value is Map) {
            result[entry.key] = Map<String, bool>.from(
              (entry.value as Map).map(
                (k, v) => MapEntry(k.toString(), v as bool),
              ),
            );
          }
        }
        _userOverrides = result;
      }
    } catch (e) {
      if (kDebugMode) print('[PermissionService] userOverrides fetch error: $e');
    }
  }

  Future<void> _fetchSuperAdmins() async {
    try {
      final snap =
          await _db.collection('siteConfig').doc('superAdmins').get();
      if (snap.exists && snap.data() != null) {
        final uids = snap.data()!['uids'];
        if (uids is List) {
          _superAdminUids = List<String>.from(uids);
        }
      }
    } catch (e) {
      if (kDebugMode) print('[PermissionService] superAdmins fetch error: $e');
    }
  }
}
