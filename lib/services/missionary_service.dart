import 'package:cloud_firestore/cloud_firestore.dart';

/// Mirrors the web's src/services/missionary.ts.
/// The web uses two separate collections — `missionary_applications` and
/// `missionary_reports` — but the mobile app previously read a single
/// non-existent `missionary-work` collection. This aligns the contract.
class MissionaryService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const String _applications = 'missionary_applications';
  static const String _reports = 'missionary_reports';

  // ── Applications ────────────────────────────────────────────────────────────

  Stream<List<Map<String, dynamic>>> watchApplications({String? userId}) {
    Query<Map<String, dynamic>> q = _db
        .collection(_applications)
        .orderBy('createdAt', descending: true);
    if (userId != null) {
      q = _db
          .collection(_applications)
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true);
    }
    return q.snapshots().map(
        (s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  Future<void> createApplication({
    required String desiredLocation,
    required String missionaryType,
    required String description,
    required String userId,
    required String fullName,
    String? phoneNumber,
  }) async {
    await _db.collection(_applications).add({
      'desiredLocation': desiredLocation,
      'missionaryType': missionaryType,
      'description': description,
      'userId': userId,
      'fullName': fullName,
      if (phoneNumber != null && phoneNumber.isNotEmpty)
        'phoneNumber': phoneNumber,
      'status': 'Pending',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Reports ─────────────────────────────────────────────────────────────────

  Stream<List<Map<String, dynamic>>> watchReports({String? missionaryId}) {
    Query<Map<String, dynamic>> q =
        _db.collection(_reports).orderBy('createdAt', descending: true);
    if (missionaryId != null) {
      q = _db
          .collection(_reports)
          .where('missionaryId', isEqualTo: missionaryId)
          .orderBy('createdAt', descending: true);
    }
    return q.snapshots().map(
        (s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  Future<void> createReport({
    required String title,
    required String location,
    required String content,
    required int peopleReached,
    required int baptized,
    required String missionaryId,
    required String date,
  }) async {
    await _db.collection(_reports).add({
      'title': title,
      'location': location,
      'content': content,
      'stats': {'peopleReached': peopleReached, 'baptized': baptized},
      'missionaryId': missionaryId,
      'date': date,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
