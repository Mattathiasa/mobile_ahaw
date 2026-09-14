/// The Standing Synod (ቋሚ ሲኖዶስ), mirroring src/services/standingSynod.ts.
///
/// Not an org unit — it is a body of people, so membership is simply the set of
/// accounts carrying the `KuamiSinodos` role. There is deliberately no separate
/// roster document: a second list of "who is on the Standing Synod" would drift
/// from the roles the permission system actually reads, and firestore.rules
/// consults the role and nothing else.
///
/// The bylaws set the body at nine. That is enforced as a warning rather than a
/// hard limit — an outgoing and an incoming member overlapping during a
/// handover is normal, and software that forbids it just gets worked around.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_model.dart';
import 'audit_log_service.dart';
import 'role_registry_service.dart';

const String kStandingSynodRole = 'KuamiSinodos';
const int kStandingSynodSeats = 9;

class StandingSynodService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Display name for a user, matching the web's
  /// `fullNameEnglish ?? fullName ?? username ?? id`.
  static String nameOf(UserModel u) =>
      u.fullNameEnglish ?? u.fullName ?? u.username;

  /// Current members.
  ///
  /// Queries on `hierarchyLevel` and sorts in memory rather than with
  /// `orderBy`, which would need a composite index and would silently drop any
  /// account missing the sorted field.
  Future<List<UserModel>> list() async {
    final snap = await _db
        .collection('users')
        .where('hierarchyLevel', isEqualTo: kStandingSynodRole)
        .get();
    final members = snap.docs.map((d) => UserModel.fromFirestore(
        d.id, d.data(), (d.data()['email'] ?? '') as String));
    final sorted = members.toList()
      ..sort((a, b) => nameOf(a).toLowerCase().compareTo(nameOf(b).toLowerCase()));
    return sorted;
  }

  /// Adds an existing account to the body.
  ///
  /// Writes `hierarchyLevel` only, which firestore.rules permits solely through
  /// its isAdmin() clause — hence the admin gate on the calling UI.
  Future<void> add(String uid, String name) async {
    await _db.collection('users').doc(uid).update({
      'hierarchyLevel': kStandingSynodRole,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await AuditLogService.dataChange(
      action: 'update',
      targetType: 'users',
      targetId: uid,
      description: 'Added $name to the Standing Synod',
    );
  }

  /// Removes somebody from the body by moving them to another role.
  ///
  /// Never deletes or suspends the account: leaving the Standing Synod does not
  /// make somebody stop being a member of the church.
  Future<void> remove(String uid, String name, String fallbackRole) async {
    await _db.collection('users').doc(uid).update({
      'hierarchyLevel': fallbackRole,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await AuditLogService.dataChange(
      action: 'update',
      targetType: 'users',
      targetId: uid,
      description: 'Removed $name from the Standing Synod',
    );
  }

  /// The roles a departing member can land in: active, non-admin, non-approver
  /// — the narrowest ordinary roles, matching the web's `memberRoles` filter.
  List<String> ordinaryRoles(RoleRegistryService registry) {
    // The registry does not currently expose its parsed role list; use the
    // seed set of ordinary levels, filtered the same way the web does.
    const seeds = ['HiyawanMahderat'];
    return seeds.where((r) => !registry.isAdminRole(r) && !registry.isApproverRole(r)).toList();
  }
}
