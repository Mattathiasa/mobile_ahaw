/// Mahedherat — the small Bible-study groups inside a congregation, mirroring
/// src/services/mahderat.ts.
///
/// Like parishes, these are `hierarchy` documents (`level: 'Mahderat'`) rather
/// than their own collection, because `users.mahderatId` already points at
/// hierarchy doc ids and `parentId` already links a group to its congregation.
///
/// Every field below is optional so a Mahderat created through the old generic
/// entity dialog stays valid.
library;

import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';

import 'audit_log_service.dart';

/// The days a Mahedher can meet, in calendar order.
const List<String> kMeetingDays = [
  'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
];

class Mahder {
  final String id;
  /// Required — `orderBy('name')` silently drops documents without it.
  final String name;
  final String? nameAmharic;
  /// The congregation (an `Atbiya` hierarchy doc id) this group belongs to.
  final String parentId;
  final double? lat;
  final double? lng;
  /// A landmark shown to members, e.g. "near Bole Medhanealem".
  final String? locationLabel;
  final String? locationLabelAm;
  final String? meetingDay;
  final String? meetingTime;
  final String? leaderName;
  final String? leaderPhone;
  final String? description;
  /// MISSING means true — groups created before this field existed.
  final bool active;

  const Mahder({
    required this.id,
    required this.name,
    this.nameAmharic,
    required this.parentId,
    this.lat,
    this.lng,
    this.locationLabel,
    this.locationLabelAm,
    this.meetingDay,
    this.meetingTime,
    this.leaderName,
    this.leaderPhone,
    this.description,
    this.active = true,
  });

  factory Mahder.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return Mahder(
      id: doc.id,
      name: (d['name'] ?? '').toString(),
      nameAmharic: d['nameAmharic'] as String?,
      parentId: (d['parentId'] ?? '').toString(),
      lat: (d['lat'] as num?)?.toDouble(),
      lng: (d['lng'] as num?)?.toDouble(),
      locationLabel: d['locationLabel'] as String?,
      locationLabelAm: d['locationLabelAm'] as String?,
      meetingDay: d['meetingDay'] as String?,
      meetingTime: d['meetingTime'] as String?,
      leaderName: d['leaderName'] as String?,
      leaderPhone: d['leaderPhone'] as String?,
      description: d['description'] as String?,
      active: d['active'] != false,
    );
  }

  bool get hasCoords => lat != null && lng != null;

  /// The visible label for where the group meets — Amharic first, matching the
  /// web's `{m.locationLabelAm || m.locationLabel}`.
  String? get locationDisplay => locationLabelAm ?? locationLabel;

  /// `Sunday · 10:00` for the list tile, empty when neither is set.
  String get meetingDisplay => [meetingDay, meetingTime]
      .whereType<String>()
      .where((s) => s.isNotEmpty)
      .join(' · ');
}

/// The typed view over Mahderat hierarchy docs, mirroring mahderatService.
class MahderatService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// The groups of one congregation.
  ///
  /// Queries on `parentId` alone and filters `level` in memory, reusing the
  /// existing hierarchy(parentId, name) index rather than needing a new
  /// composite one — the same trade `atbiyaAdminService.list` makes.
  Future<List<Mahder>> listByCongregation(String atbiyaId,
      {bool includeInactive = false}) async {
    if (atbiyaId.isEmpty) return [];
    final snap = await _db
        .collection('hierarchy')
        .where('parentId', isEqualTo: atbiyaId)
        .orderBy('name')
        .get();
    final all =
        snap.docs.map(Mahder.fromDoc).where((m) => m.parentId == atbiyaId).toList();
    return includeInactive ? all : all.where((m) => m.active).toList();
  }

  Future<Mahder?> getById(String id) async {
    if (id.isEmpty) return null;
    final snap = await _db.collection('hierarchy').doc(id).get();
    if (!snap.exists) return null;
    final m = Mahder.fromDoc(snap);
    return m.id == id && m.name.isNotEmpty ? m : null;
  }

  /// Payload for [create]/[update] from the form-sheet field controllers.
  ///
  /// Carries `parentId` — [create] needs it to attach the group to its
  /// congregation, and [update] strips it because the rules never allow a
  /// congregation change. Deliberately does not carry `active`: editing a
  /// hidden group must not silently re-activate it — that is the Hide/Show
  /// action's job. [create] adds `active: true` itself.
  Map<String, dynamic> mahderPayload({
    required String name,
    String? nameAmharic,
    required String parentId,
    String? locationLabel,
    String? locationLabelAm,
    String? meetingDay,
    String? meetingTime,
    String? leaderName,
    String? leaderPhone,
    String? description,
  }) =>
      {
        'name': name.trim(),
        'nameAmharic': (nameAmharic ?? '').trim(),
        'parentId': parentId,
        'locationLabel': (locationLabel ?? '').trim(),
        'locationLabelAm': (locationLabelAm ?? '').trim(),
        'meetingDay': meetingDay ?? '',
        'meetingTime': (meetingTime ?? '').trim(),
        'leaderName': (leaderName ?? '').trim(),
        'leaderPhone': (leaderPhone ?? '').trim(),
        'description': (description ?? '').trim(),
      };

  Future<void> create(Map<String, dynamic> data) async {
    final ref = await _db.collection('hierarchy').add({
      ...data,
      'level': 'Mahderat',
      'active': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await AuditLogService.dataChange(
      action: 'create',
      targetType: 'hierarchy',
      targetId: ref.id,
      description: 'Created Mahedher ${data['name'] ?? ''}'.trim(),
    );
  }

  /// `level` and `parentId` are never sent: the rules reject a congregation
  /// changing either, and sending them unchanged still trips the affectedKeys
  /// check on some Firestore versions — the same reason MyAtbiya strips them.
  Future<void> update(String id, Map<String, dynamic> data) async {
    final payload = {...data}..remove('parentId');
    await _db.collection('hierarchy').doc(id).update({
      ...payload,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await AuditLogService.dataChange(
      action: 'update',
      targetType: 'hierarchy',
      targetId: id,
      description: 'Updated Mahedher ${data['name'] ?? id}',
    );
  }

  /// Deactivates rather than deletes — `users.mahderatId` and the finance
  /// collections reference these ids, and removing the document orphans them.
  Future<void> setActive(String id, bool active) async {
    await _db.collection('hierarchy').doc(id).update({
      'active': active,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await AuditLogService.dataChange(
      action: 'update',
      targetType: 'hierarchy',
      targetId: id,
      description: active ? 'Reactivated Mahedher' : 'Deactivated Mahedher',
    );
  }

  /// Records the member's own choice of group.
  Future<void> joinAsMember(String uid, String mahderId) async {
    await _db.collection('users').doc(uid).update({
      'mahderatId': mahderId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Great-circle distance in kilometres between two coordinates — used to
  /// rank the groups nearest a member's saved home location.
  static double distanceKm(
      double lat1, double lng1, double lat2, double lng2) {
    const p = 0.017453292519943295; // π/180
    final a = 0.5 -
        math.cos((lat2 - lat1) * p) / 2 +
        math.cos(lat1 * p) * math.cos(lat2 * p) * (1 - math.cos((lng2 - lng1) * p)) / 2;
    return 12742 * math.asin(math.sqrt(a)); // 2 × R (Earth's radius in km)
  }
}
