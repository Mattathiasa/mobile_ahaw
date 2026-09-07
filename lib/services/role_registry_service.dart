import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// What slice of data a role can see. Mirrors `RoleScope` in
/// src/services/roleRegistry.ts.
enum RoleScope { global, zone, atbiya, mahder }

/// The member-directory scope a user is entitled to, mirroring
/// `canReadWholeDirectory` + `myAtbiyaId` in the web's PermissionContext.
class MemberScope {
  final bool wholeDirectory;
  final String atbiyaId;
  const MemberScope({required this.wholeDirectory, required this.atbiyaId});
}

/// Consumes the web's role registry (`siteConfig/roles`). The mobile app only
/// READS it — editing stays on the web (Software Control) per the operational-
/// first scope. Used to resolve a role's data scope so member/dashboard reads
/// stay inside what firestore.rules will allow (a parish role reading the whole
/// `users` collection is denied by the rules).
class RoleRegistryService extends ChangeNotifier {
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;

  Map<String, _RoleInfo> _roles = {};

  /// Built-in role scopes (SEED_SPECS in roleRegistry.ts). Used as an instant
  /// fallback before the Firestore registry resolves, and for the system roles
  /// generally (their scopes are fixed by the bylaws).
  static const Map<String, RoleScope> _seedScopes = {
    'SuperAdmin': RoleScope.global,
    'Sinodos': RoleScope.global,
    'KuamiSinodos': RoleScope.global,
    'Memriya': RoleScope.global,
    'Zone': RoleScope.zone,
    'Atbiya': RoleScope.atbiya,
    'EnkesekaseMaikel': RoleScope.atbiya,
    'HiyawanMahderat': RoleScope.mahder,
  };
  static const Set<String> _seedAdmins = {
    'SuperAdmin',
    'Sinodos',
    'KuamiSinodos',
  };
  static const Set<String> _seedApprovers = {
    'SuperAdmin',
    'Sinodos',
    'KuamiSinodos',
    'Memriya',
    'Zone',
    'Atbiya',
  };

  RoleRegistryService() {
    _init();
  }

  void _init() {
    _sub = FirebaseFirestore.instance
        .collection('siteConfig')
        .doc('roles')
        .snapshots()
        .listen((snap) {
      final rolesRaw = snap.data()?['roles'];
      if (rolesRaw is! List) return;
      final map = <String, _RoleInfo>{};
      for (final r in rolesRaw) {
        if (r is Map) {
          final key = r['key']?.toString();
          if (key == null || key.isEmpty) continue;
          map[key] = _RoleInfo(
            scope: _parseScope(r['scope']?.toString()),
            isAdmin: r['isAdmin'] == true,
            canApproveMembers: r['canApproveMembers'] == true,
            labels: (r['labels'] is Map)
                ? Map<String, dynamic>.from(r['labels'] as Map)
                : const {},
          );
        }
      }
      _roles = map;
      notifyListeners();
    }, onError: (e) {
      if (kDebugMode) print('[RoleRegistry] listen failed: $e');
    });
  }

  static RoleScope _parseScope(String? s) {
    switch (s) {
      case 'global':
        return RoleScope.global;
      case 'zone':
        return RoleScope.zone;
      case 'atbiya':
        return RoleScope.atbiya;
      case 'mahder':
      default:
        return RoleScope.mahder;
    }
  }

  RoleScope scopeOf(String? key) {
    if (key == null) return RoleScope.mahder;
    return _roles[key]?.scope ?? _seedScopes[key] ?? RoleScope.mahder;
  }

  bool isAdminRole(String? key) {
    if (key == null) return false;
    return _roles[key]?.isAdmin ?? _seedAdmins.contains(key);
  }

  bool isApproverRole(String? key) {
    if (key == null) return false;
    return _roles[key]?.canApproveMembers ?? _seedApprovers.contains(key);
  }

  String roleLabel(String? key, String lang) {
    if (key == null) return '';
    final labels = _roles[key]?.labels;
    if (labels != null) {
      final v = labels[lang] ?? labels['en'];
      if (v is String && v.isNotEmpty) return v;
    }
    return key;
  }

  MemberScope memberScopeFor({
    required String? roleKey,
    required bool isSuperAdmin,
    required String atbiyaId,
  }) {
    final scope = scopeOf(roleKey);
    final headOffice = isSuperAdmin || scope == RoleScope.global;
    final wholeDirectory = headOffice || scope == RoleScope.zone;
    return MemberScope(wholeDirectory: wholeDirectory, atbiyaId: atbiyaId);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

class _RoleInfo {
  final RoleScope scope;
  final bool isAdmin;
  final bool canApproveMembers;
  final Map<String, dynamic> labels;
  const _RoleInfo({
    required this.scope,
    required this.isAdmin,
    required this.canApproveMembers,
    required this.labels,
  });
}
