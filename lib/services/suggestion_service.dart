import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Public suggestion box, mirroring the web's src/services/suggestions.ts.
///
/// firestore.rules requires a uid on every submission, so a visitor with no
/// account gets a throwaway anonymous session minted at submit time, used, and
/// dropped. A signed-in member keeps their real session and is recorded as a
/// member. Relies on AuthService treating anonymous sessions as unauthenticated.
class SuggestionService {
  Future<void> submit({
    required String category,
    required String message,
    String name = '',
    String contact = '',
    String language = 'am',
  }) async {
    final auth = FirebaseAuth.instance;
    final db = FirebaseFirestore.instance;
    final hadSession =
        auth.currentUser != null && !auth.currentUser!.isAnonymous;

    if (auth.currentUser == null) {
      try {
        await auth.signInAnonymously();
      } on FirebaseAuthException catch (e) {
        throw e.code == 'operation-not-allowed'
            ? 'Anonymous submissions are disabled. Please sign in to send a suggestion.'
            : 'Could not send your suggestion. Please try again.';
      }
    }

    final uid = auth.currentUser?.uid;
    if (uid == null) throw 'Could not send your suggestion.';

    try {
      await db.collection('suggestions').add({
        'category': category,
        'message': message.trim(),
        'name': name.trim(),
        'contact': contact.trim(),
        'language': language,
        'status': 'New',
        'authorUid': uid,
        'isMember': hadSession,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } finally {
      // Drop the throwaway session only if we minted it.
      if (!hadSession && (auth.currentUser?.isAnonymous ?? false)) {
        await auth.signOut().catchError((_) {});
      }
    }
  }
}
