import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

/// User/member directory service. Mirrors the relevant parts of the web's
/// src/services/users.ts + members. Consolidated here (there is no separate
/// users_service) so both the Members directory and User Management use one
/// source of truth.
class MemberService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Deterministic synthetic sign-in address for accounts created without a
  /// real inbox — matches the web's syntheticEmail() so username login resolves.
  static String syntheticEmail(String username) {
    final clean = username.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return '$clean@mahibereahaw.local';
  }

  static bool isSyntheticEmail(String email) =>
      email.toLowerCase().endsWith('@mahibereahaw.local');

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

  Future<Map<String, dynamic>?> getUserById(String id) async {
    final snap = await _db.collection('users').doc(id).get();
    if (!snap.exists) return null;
    return {'id': snap.id, ...?snap.data()};
  }

  Future<List<Map<String, dynamic>>> getUsersByAtbiya(String atbiyaId) async {
    if (atbiyaId.isEmpty) return [];
    final snap = await _db
        .collection('users')
        .where('atbiyaId', isEqualTo: atbiyaId)
        .get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  /// Creates a member with a real Firebase Auth account so they can sign in,
  /// mirroring the web's userService.createUser. The auth account is created on
  /// a SECONDARY Firebase app so the admin's own session is untouched; the
  /// password is never written to Firestore.
  Future<String> createMember(Map<String, dynamic> memberData) async {
    final password = (memberData['password'] as String?)?.trim();
    if (password == null || password.isEmpty) {
      throw 'A password is required to create a member.';
    }
    final username = (memberData['username'] as String?)?.trim() ??
        'user${DateTime.now().millisecondsSinceEpoch}';
    final contactEmail = (memberData['email'] as String?)?.trim() ?? '';
    final hasRealInbox =
        contactEmail.isNotEmpty && !isSyntheticEmail(contactEmail);
    final loginEmail =
        hasRealInbox ? contactEmail.toLowerCase() : syntheticEmail(username);

    final secondaryApp = await Firebase.initializeApp(
      name: 'MemberCreate-${DateTime.now().millisecondsSinceEpoch}',
      options: Firebase.app().options,
    );
    try {
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      final cred = await secondaryAuth.createUserWithEmailAndPassword(
        email: loginEmail,
        password: password,
      );
      final id = cred.user!.uid;

      final toSave = Map<String, dynamic>.from(memberData)
        ..remove('password')
        ..['email'] = contactEmail
        ..['username'] = username
        ..['fullNameEnglish'] =
            memberData['fullNameEnglish'] ?? memberData['fullName'] ?? ''
        ..['role'] = memberData['role'] ?? 'user'
        ..['status'] = memberData['status'] ?? 'active'
        ..['signupSource'] = memberData['signupSource'] ?? 'admin'
        ..['createdAt'] = FieldValue.serverTimestamp()
        ..['updatedAt'] = FieldValue.serverTimestamp();

      // Written via the PRIMARY db (the admin's session), which is what holds
      // permission to create a member record.
      await _db.collection('users').doc(id).set(toSave);

      // Username reservation is written via the SECONDARY app (signed in as the
      // new account) because the rules only accept an email on that row from
      // its owner. Best-effort.
      try {
        await FirebaseFirestore.instanceFor(app: secondaryApp)
            .collection('usernames')
            .doc(username.toLowerCase())
            .set({
          'uid': id,
          if (hasRealInbox) 'email': loginEmail,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {/* non-fatal */}

      return id;
    } finally {
      await secondaryApp.delete();
    }
  }

  Future<void> updateMember(String id, Map<String, dynamic> memberData) async {
    await _db.collection('users').doc(id).update({
      ...memberData,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Suspends an account (soft delete) rather than removing the document, so
  /// access is actually revoked by `isActive()` in firestore.rules — mirrors
  /// the web's userService.deleteUser. A hard delete left the Auth login able
  /// to sign in with a default profile.
  Future<void> suspendMember(String id) async {
    await _db.collection('users').doc(id).update({
      'status': 'suspended',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Permanently deletes the member record (not the Auth credential, which
  /// needs the Admin SDK). Use sparingly; prefer [suspendMember].
  Future<void> purgeMember(String id) async {
    await _db.collection('users').doc(id).delete();
  }

  /// Recent audit-log entries for the User Management log view. Reads
  /// `auditLogs` (the collection the mobile app + web both write).
  Future<List<Map<String, dynamic>>> getAuditLogs({int limit = 20}) async {
    try {
      final snap = await _db
          .collection('auditLogs')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    } catch (_) {
      return [];
    }
  }
}
