import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Public member self sign-up, mirroring the web's src/services/signup.ts.
///
/// Creates the Firebase Auth account immediately but writes the Firestore
/// profile with `status: 'pending'`. firestore.rules denies all data access
/// until an approver flips it to 'active', so a pending member can authenticate
/// and see nothing — the block is server-side. The sign-in address is always
/// synthetic (username@mahibereahaw.local); the real email is stored as
/// access-controlled contact data.
class SignupService {
  static const String syntheticDomain = 'mahibereahaw.local';

  static String syntheticEmail(String username) {
    final clean = username.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return '$clean@$syntheticDomain';
  }

  Future<bool> isUsernameTaken(String username) async {
    final key = username.trim().toLowerCase();
    if (key.isEmpty) return false;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('usernames')
          .doc(key)
          .get();
      return snap.exists;
    } catch (_) {
      // A failed lookup must not block sign-up; Auth still enforces uniqueness.
      return false;
    }
  }

  Future<void> register({
    required String fullNameEnglish,
    required String fullNameAmharic,
    required String username,
    required String email,
    required String password,
    required String phone,
    String gender = '',
    String dateOfBirth = '',
    required String atbiyaId,
    required String atbiyaName,
  }) async {
    final auth = FirebaseAuth.instance;
    final db = FirebaseFirestore.instance;
    final uname = username.trim();
    final loginEmail = syntheticEmail(uname);

    String? uid;
    try {
      final cred = await auth.createUserWithEmailAndPassword(
          email: loginEmail, password: password);
      uid = cred.user!.uid;

      // The self-signup role, from roleFlags (falls back to the seed default).
      String signupRole = 'HiyawanMahderat';
      try {
        final flags =
            await db.collection('siteConfig').doc('roleFlags').get();
        final sr = flags.data()?['signupRole'];
        if (sr is String && sr.isNotEmpty) signupRole = sr;
      } catch (_) {}

      // This object must match the keys().hasOnly([...]) whitelist in
      // firestore.rules exactly — an extra field makes the whole write fail.
      final profile = {
        'username': uname,
        'email': email.trim(),
        'fullNameEnglish': fullNameEnglish.trim(),
        'fullNameAmharic': fullNameAmharic.trim(),
        'fullName': fullNameEnglish.trim(),
        'phone': phone.trim(),
        'dateOfBirth': dateOfBirth,
        'gender': gender,
        'maritalStatus': '',
        'hasChildren': false,
        'childrenCount': 0,
        'workSchool': '',
        'address': {'region': '', 'zone': '', 'woreda': ''},
        'ministryType': <String>[],
        'churchRoles': <String>[],
        'atbiyaId': atbiyaId,
        'atbiyaName': atbiyaName,
        'hierarchyLevel': signupRole,
        'role': 'user',
        'status': 'pending',
        'signupSource': 'self',
        'requestedAt': DateTime.now().toIso8601String(),
        'createdAt': DateTime.now().toIso8601String(),
      };

      await db.collection('users').doc(uid).set(profile);

      // Reserve the username (world-readable; no email stored). Best-effort.
      try {
        await db.collection('usernames').doc(uname.toLowerCase()).set({
          'uid': uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {}

      // Never leave the caller holding a half-authorised pending session.
      await auth.signOut();
    } on FirebaseAuthException catch (e) {
      await _rollback(auth, uid);
      throw _friendlyError(e);
    } catch (_) {
      await _rollback(auth, uid);
      throw 'Could not complete your registration. Please try again.';
    }
  }

  Future<void> _rollback(FirebaseAuth auth, String? uid) async {
    // If Auth succeeded but the profile write failed, the account would be
    // stranded (can sign in, no document, no queue). Roll it back.
    if (uid != null && auth.currentUser?.uid == uid) {
      try {
        await auth.currentUser!.delete();
      } catch (_) {
        await auth.signOut().catchError((_) {});
      }
    }
  }

  String _friendlyError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'That username is already taken. Please choose another.';
      case 'invalid-email':
        return 'The username produced an invalid sign-in address.';
      case 'weak-password':
        return 'Please choose a password of at least 6 characters.';
      case 'network-request-failed':
        return 'Network problem — check your connection and try again.';
      case 'operation-not-allowed':
        return 'Sign-up is disabled for this project. Ask an administrator.';
      default:
        return e.message ?? 'Could not complete your registration.';
    }
  }
}
