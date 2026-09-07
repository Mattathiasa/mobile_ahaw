import 'package:cloud_firestore/cloud_firestore.dart';


class MemberService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// The whole directory, unfiltered. Firestore now allows this only for a
  /// caller with global/zone scope; a parish-scoped caller is denied. Prefer
  /// [getMembersInScope].
  Future<List<Map<String, dynamic>>> getAllMembers() async {
    final snapshot = await _db.collection('users').get();
    return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  }

  /// The directory a caller is actually entitled to see, mirroring the web's
  /// `userService.getUsersInScope`. Head office / diocese read it all; everyone
  /// else reads their own congregation via the `atbiyaId` equality filter the
  /// list rule requires; a caller with neither sees nobody.
  Future<List<Map<String, dynamic>>> getMembersInScope({
    required bool wholeDirectory,
    String? atbiyaId,
  }) async {
    if (wholeDirectory) return getAllMembers();
    if (atbiyaId == null || atbiyaId.isEmpty) return [];
    final snapshot = await _db
        .collection('users')
        .where('atbiyaId', isEqualTo: atbiyaId)
        .get();
    final users =
        snapshot.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    users.sort((a, b) => (a['fullNameEnglish'] ?? a['fullName'] ?? '')
        .toString()
        .compareTo((b['fullNameEnglish'] ?? b['fullName'] ?? '').toString()));
    return users;
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
