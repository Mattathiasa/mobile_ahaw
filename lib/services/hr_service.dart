import 'package:cloud_firestore/cloud_firestore.dart';

/// Employee/HR records, mirroring the web's src/services/hr.ts
/// (`employees` collection). The mobile form covers the core fields; the web
/// keeps the full payroll detail.
class HrService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _col = 'employees';

  Stream<List<Map<String, dynamic>>> watchEmployees() {
    return _db.collection(_col).orderBy('fullName').snapshots().map(
        (s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  Future<void> create(Map<String, dynamic> data) async {
    await _db.collection(_col).add({
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> update(String id, Map<String, dynamic> data) async {
    await _db.collection(_col).doc(id).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> remove(String id) async {
    await _db.collection(_col).doc(id).delete();
  }
}
