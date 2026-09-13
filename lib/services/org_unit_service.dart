/// The church's organisational units, mirroring src/services/orgUnits.ts.
///
/// Every level lives in the same `hierarchy` collection, discriminated by
/// `level` and linked by `parentId` — the arrangement congregations and
/// Mahedherat already use. This module is the typed view over all of it, so the
/// registries do not each re-derive what a level's parent is.
///
/// Two levels are new here: `Teklay` (ጠቅላይ ጽሕፈት ቤት) and `Woreda`. Neither
/// displaces anything: a Diocese whose `parentId` still points at a Memriya
/// document, or at nothing at all, keeps working.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import 'audit_log_service.dart';

/// The organisational levels, in chart order.
const List<String> kOrgLevels = [
  'Teklay',
  'Memriya',
  'Zone',
  'Woreda',
  'Atbiya',
  'Mahderat',
];

/// Which level a unit of [level] hangs off, or null for the root.
String? parentLevelOf(String level) {
  switch (level) {
    case 'Teklay':
      return null; // Root — there is only ever one.
    case 'Memriya':
    case 'Zone':
      return 'Teklay';
    case 'Woreda':
    case 'Atbiya':
      return 'Zone';
    case 'Mahderat':
      return 'Atbiya';
  }
  return null;
}

class OrgUnit {
  final String id;
  final String name;
  final String? nameAmharic;
  final String level;
  final String? parentId;
  final String? leaderName;
  final String? leaderPhone;
  final String? location;
  final double? lat;
  final double? lng;
  final String? description;
  /// Ethiopian-calendar date as written in the register.
  final String? foundedAt;
  /// Meeting fields — only ever populated on Mahderat docs (same collection,
  /// so the typed model carries both shapes), mirroring the Mahder model.
  final String? meetingDay;
  final String? meetingTime;
  /// MISSING means true — units created before this field existed.
  final bool active;

  const OrgUnit({
    required this.id,
    required this.name,
    this.nameAmharic,
    required this.level,
    this.parentId,
    this.leaderName,
    this.leaderPhone,
    this.location,
    this.lat,
    this.lng,
    this.description,
    this.foundedAt,
    this.meetingDay,
    this.meetingTime,
    this.active = true,
  });

  factory OrgUnit.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return OrgUnit(
      id: doc.id,
      name: (d['name'] ?? '').toString(),
      nameAmharic: d['nameAmharic'] as String?,
      level: (d['level'] ?? '').toString(),
      parentId: d['parentId'] as String?,
      leaderName: d['leaderName'] as String?,
      leaderPhone: d['leaderPhone'] as String?,
      location: d['location'] as String?,
      lat: (d['lat'] as num?)?.toDouble(),
      lng: (d['lng'] as num?)?.toDouble(),
      description: d['description'] as String?,
      foundedAt: d['foundedAt'] as String?,
      meetingDay: d['meetingDay'] as String?,
      meetingTime: d['meetingTime'] as String?,
      active: d['active'] != false,
    );
  }

  /// The pin, or null when this unit has never been placed on the map.
  bool get hasCoords => lat != null && lng != null;

  /// `Sunday · 10:00` for a Mahderat list tile, empty when neither is set.
  String get meetingDisplay => [meetingDay, meetingTime]
      .whereType<String>()
      .where((s) => s.isNotEmpty)
      .join(' · ');
}

/// The typed view over the `hierarchy` collection, mirroring
/// orgUnitService in src/services/orgUnits.ts.
class OrgUnitService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Every unit at one level.
  ///
  /// Uses the equality-filtered `level` query so it rides the existing
  /// hierarchy(level, name) index, and filters `active` in memory because a
  /// `where('active','==',true)` clause would exclude every document created
  /// before the field existed.
  Future<List<OrgUnit>> listByLevel(String level, {bool includeInactive = false}) async {
    final snap = await _db
        .collection('hierarchy')
        .where('level', isEqualTo: level)
        .orderBy('name')
        .get();
    final all = snap.docs.map(OrgUnit.fromDoc).toList();
    return includeInactive ? all : all.where((u) => u.active).toList();
  }

  /// Live stream of one level, for registry screens.
  Stream<List<OrgUnit>> streamByLevel(String level) {
    return _db
        .collection('hierarchy')
        .where('level', isEqualTo: level)
        .orderBy('name')
        .snapshots()
        .map((snap) => snap.docs.map(OrgUnit.fromDoc).toList());
  }

  /// Children of one unit, at whatever level they happen to be.
  Future<List<OrgUnit>> listByParent(String parentId, {bool includeInactive = false}) async {
    if (parentId.isEmpty) return [];
    final snap = await _db
        .collection('hierarchy')
        .where('parentId', isEqualTo: parentId)
        .orderBy('name')
        .get();
    final all = snap.docs.map(OrgUnit.fromDoc).toList();
    return includeInactive ? all : all.where((u) => u.active).toList();
  }

  /// The single ጠቅላይ ጽሕፈት ቤት record, or null before one is created.
  ///
  /// Returns the first if somehow several exist rather than throwing — a
  /// duplicate is a data problem for an administrator to resolve, not a
  /// reason for the page to fail to load.
  Future<OrgUnit?> getSecretariat() async {
    final all = await listByLevel('Teklay', includeInactive: true);
    return all.isEmpty ? null : all.first;
  }

  Future<OrgUnit?> getById(String id) async {
    if (id.isEmpty) return null;
    final snap = await _db.collection('hierarchy').doc(id).get();
    if (!snap.exists) return null;
    return OrgUnit.fromDoc(snap);
  }

  /// Payload for [create]/[update] from the form-sheet field controllers.
  ///
  /// Deliberately does not carry `active`: editing a hidden unit must not
  /// silently re-activate it — that is the Hide/Show action's job. [create]
  /// adds `active: true` itself.
  Map<String, dynamic> unitPayload({
    required String name,
    String? nameAmharic,
    String? parentId,
    String? leaderName,
    String? leaderPhone,
    String? location,
    String? description,
    String? foundedAt,
  }) =>
      {
        'name': name.trim(),
        'nameAmharic': (nameAmharic ?? '').trim(),
        'parentId': (parentId ?? '').isEmpty ? null : parentId,
        'leaderName': (leaderName ?? '').trim(),
        'leaderPhone': (leaderPhone ?? '').trim(),
        'location': (location ?? '').trim(),
        'description': (description ?? '').trim(),
        'foundedAt': (foundedAt ?? '').trim(),
      };

  Future<void> create(String level, Map<String, dynamic> data) async {
    final ref = await _db.collection('hierarchy').add({
      ...data,
      'level': level,
      'active': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await AuditLogService.dataChange(
      action: 'create',
      targetType: 'hierarchy',
      targetId: ref.id,
      description: 'Created $level ${data['name'] ?? ''}'.trim(),
    );
  }

  Future<void> update(String id, Map<String, dynamic> data) async {
    await _db.collection('hierarchy').doc(id).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await AuditLogService.dataChange(
      action: 'update',
      targetType: 'hierarchy',
      targetId: id,
      description: 'Updated ${data['name'] ?? id}',
    );
  }

  /// Deactivates rather than deletes. `users.atbiyaId`, `users.mahderatId`,
  /// `news.atbiyaId` and every child unit's `parentId` reference these ids, so
  /// removing a document would orphan them.
  Future<void> setActive(String id, bool active) async {
    await _db.collection('hierarchy').doc(id).update({
      'active': active,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await AuditLogService.dataChange(
      action: 'update',
      targetType: 'hierarchy',
      targetId: id,
      description: active ? 'Reactivated org unit' : 'Deactivated org unit',
    );
  }

  /// How many children each unit at [childLevel] has, keyed by parent id.
  ///
  /// One query for the whole level rather than one per parent — a registry of
  /// twenty dioceses would otherwise fire twenty reads just to draw its badges.
  Future<Map<String, int>> childCounts(String childLevel) async {
    final children = await listByLevel(childLevel, includeInactive: true);
    final counts = <String, int>{};
    for (final c in children) {
      final p = c.parentId;
      if (p != null && p.isNotEmpty) counts[p] = (counts[p] ?? 0) + 1;
    }
    return counts;
  }
}
