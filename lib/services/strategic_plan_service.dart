import 'package:cloud_firestore/cloud_firestore.dart';

/// Mirrors the web's src/services/strategicPlan.ts.
/// Reads/writes the shared `strategic_plans` Firestore collection so the
/// mobile app and web app stay in sync (previously the mobile app read a
/// non-existent `strategic-goals` collection and fell back to mock data).
class StrategicPlanService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _col = 'strategic_plans';

  /// Live stream of goals, ordered by target year (ascending) — same order
  /// as the web's `getAllGoals()`.
  Stream<List<Map<String, dynamic>>> watchGoals() {
    return _db
        .collection(_col)
        .orderBy('targetYear')
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  Future<void> createGoal(Map<String, dynamic> goal) async {
    await _db.collection(_col).add({
      ...goal,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateGoal(String id, Map<String, dynamic> updates) async {
    await _db.collection(_col).doc(id).update({
      ...updates,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteGoal(String id) async {
    await _db.collection(_col).doc(id).delete();
  }
}
