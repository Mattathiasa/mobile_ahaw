import 'package:cloud_firestore/cloud_firestore.dart';


class MemberService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<List<Map<String, dynamic>>> getAllMembers() async {
    final snapshot = await _db.collection('users').get();
    return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  }

  Future<void> createMember(Map<String, dynamic> memberData) async {
    // Note: Creating a secondary auth user in Flutter is complex 
    // because it might interfere with the current session.
    // For now, we will just add the user to Firestore.
    // In a real app, this should be done via Cloud Functions or a secondary app.
    
    final id = _db.collection('users').doc().id;
    await _db.collection('users').doc(id).set({
      ...memberData,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateMember(String id, Map<String, dynamic> memberData) async {
    await _db.collection('users').doc(id).update({
      ...memberData,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteMember(String id) async {
    await _db.collection('users').doc(id).delete();
  }
}
