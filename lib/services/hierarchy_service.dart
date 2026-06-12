import 'package:cloud_firestore/cloud_firestore.dart';

class HierarchyService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<Map<String, dynamic>>> getEntitiesByLevel(String level) {
    return _db
        .collection('hierarchy')
        .where('level', isEqualTo: level)
        .orderBy('name', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList());
  }

  Stream<List<Map<String, dynamic>>> getEntitiesByParent(String parentId) {
    return _db
        .collection('hierarchy')
        .where('parentId', isEqualTo: parentId)
        .orderBy('name', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList());
  }

  Future<void> createEntity(Map<String, dynamic> data) async {
    await _db.collection('hierarchy').add({
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateEntity(String id, Map<String, dynamic> data) async {
    await _db.collection('hierarchy').doc(id).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteEntity(String id) async {
    await _db.collection('hierarchy').doc(id).delete();
  }
}
