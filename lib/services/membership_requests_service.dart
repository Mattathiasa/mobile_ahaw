import 'package:cloud_firestore/cloud_firestore.dart';

/// Membership sign-up requests, mirroring the web's membershipRequests.ts.
/// A request IS the `users/{uid}` document sitting at `status: 'pending'`;
/// approval/rejection is a single field flip done in a transaction so two
/// approvers cannot both win. The member is notified of the decision.
class MembershipRequestsService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Pending requests. Head office passes no [atbiyaId] and sees all; a parish
  /// passes its own and sees only its own (matches the directory rule).
  Future<List<Map<String, dynamic>>> listPending({String? atbiyaId}) async {
    Query<Map<String, dynamic>> q;
    if (atbiyaId != null && atbiyaId.isNotEmpty) {
      q = _db
          .collection('users')
          .where('status', isEqualTo: 'pending')
          .where('atbiyaId', isEqualTo: atbiyaId)
          .orderBy('requestedAt', descending: true);
    } else {
      q = _db
          .collection('users')
          .where('status', isEqualTo: 'pending')
          .orderBy('requestedAt', descending: true);
    }
    final snap = await q.get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  Future<void> approve({
    required String uid,
    required String approverId,
    required String roleKey,
  }) async {
    final ref = _db.collection('users').doc(uid);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw 'This request no longer exists.';
      if (snap.data()?['status'] != 'pending') {
        throw 'This request was already decided by someone else.';
      }
      tx.update(ref, {
        'status': 'active',
        'hierarchyLevel': roleKey,
        'approvedBy': approverId,
        'approvedAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });
    });
    await _notify(uid, 'የአባልነት ጥያቄ ጸድቋል',
        'የአባልነት ጥያቄዎ ጸድቋል። እንኳን ደህና መጡ!', 'success');
  }

  Future<void> reject({
    required String uid,
    required String approverId,
    required String reason,
  }) async {
    final ref = _db.collection('users').doc(uid);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw 'This request no longer exists.';
      if (snap.data()?['status'] != 'pending') {
        throw 'This request was already decided.';
      }
      tx.update(ref, {
        'status': 'rejected',
        'rejectedBy': approverId,
        'rejectedAt': DateTime.now().toIso8601String(),
        'rejectedReason': reason.trim(),
        'updatedAt': DateTime.now().toIso8601String(),
      });
    });
    await _notify(
        uid,
        'የአባልነት ጥያቄ ውሳኔ',
        reason.trim().isEmpty ? 'የአባልነት ጥያቄዎ ተቀባይነት አላገኘም።' : reason.trim(),
        'warning');
  }

  /// Decision notifications are written in Amharic (the member reads them, not
  /// the approver), matching the web. Best-effort.
  Future<void> _notify(
      String uid, String title, String message, String type) async {
    try {
      await _db.collection('notifications').add({
        'userId': uid,
        'title': title,
        'message': message,
        'type': type,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }
}
