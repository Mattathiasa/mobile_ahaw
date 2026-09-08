import 'package:cloud_firestore/cloud_firestore.dart';

/// Church asset inventory, mirroring the web's src/services/inventory.ts
/// (`assets` collection).
class InventoryService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _col = 'assets';

  Stream<List<Map<String, dynamic>>> watchAssets() {
    return _db.collection(_col).orderBy('name').snapshots().map(
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
