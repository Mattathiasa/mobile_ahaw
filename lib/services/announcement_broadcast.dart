/// Delivering an announcement to the people it is meant for.
///
/// This is how an ordinary member sees an announcement at all: they have no
/// Announcements screen, so the only thing that reaches them is a notification.
/// The app used to write the announcement document and stop, which meant an
/// announcement created on a phone reached nobody.
///
/// Targeting happens HERE, on the client, by resolving the audience to real
/// people and writing one notification each — the same design as the web's
/// `broadcast` in src/services/announcements.ts. It is not a topic broadcast:
/// a topic cannot express "only Memriya", and the undeployed Cloud Function
/// that pushes to the `announcements` topic sends to every subscriber whatever
/// audience was chosen.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'member_service.dart';

/// Who an announcement is for. Stored on the announcement document in the same
/// shape the web writes, so an announcement made on either client reads the
/// same on both — see `AnnouncementAudience` in src/services/announcements.ts.
class AnnouncementAudience {
  /// 'everyone' | 'parish' | 'roles'
  final String kind;

  /// Set when [kind] is 'parish'.
  final String atbiyaId;

  /// Set when [kind] is 'roles'; hierarchy level keys from the role registry.
  final List<String> roles;

  const AnnouncementAudience.everyone()
      : kind = 'everyone',
        atbiyaId = '',
        roles = const [];

  const AnnouncementAudience.parish(this.atbiyaId)
      : kind = 'parish',
        roles = const [];

  const AnnouncementAudience.roles(this.roles)
      : kind = 'roles',
        atbiyaId = '';

  Map<String, dynamic> toMap() => {
        'kind': kind,
        if (kind == 'parish') 'atbiyaId': atbiyaId,
        if (kind == 'roles') 'roles': roles,
      };
}

/// Firestore caps a batch at 500 writes. The web uses 450 for headroom; the
/// same number here keeps a send that succeeds on one client succeeding on the
/// other.
const int kNotificationBatchLimit = 450;

/// The keys firestore.rules accepts on a notification:
///
///   allow create: if isActive()
///     && request.resource.data.senderId == request.auth.uid
///     && request.resource.data.get('senderName', '') in [ '', ...the
///          caller's own fullNameEnglish / fullName / username ]
///     && request.resource.data.keys().hasOnly([...]);
///
/// hasOnly() fails the whole write on one unexpected key.
const kNotificationKeys = <String>[
  'userId', 'senderId', 'senderName', 'title', 'message', 'type',
  'link', 'status', 'createdAt',
];

/// Chooses which members an [audience] actually refers to.
///
/// Pure, so it can be checked without Firestore. [members] is whatever the
/// caller was entitled to read — see [AnnouncementBroadcast.resolveRecipients]
/// for why that is not always everybody.
List<Map<String, dynamic>> filterRecipients(
  List<Map<String, dynamic>> members,
  AnnouncementAudience audience, {
  String? authorId,
}) {
  return members.where((u) {
    // The author does not need telling about their own announcement.
    if (authorId != null && authorId.isNotEmpty && u['id'] == authorId) {
      return false;
    }
    // A missing status means active — every account that predates sign-up.
    if ((u['status'] ?? 'active') != 'active') return false;
    if (audience.kind == 'roles') {
      final level = u['hierarchyLevel'];
      return level is String &&
          level.isNotEmpty &&
          audience.roles.contains(level);
    }
    return true;
  }).toList();
}

/// Splits [items] into batches no larger than [size].
List<List<T>> chunk<T>(List<T> items, [int size = kNotificationBatchLimit]) {
  final out = <List<T>>[];
  for (var i = 0; i < items.length; i += size) {
    out.add(items.sublist(i, i + size > items.length ? items.length : i + size));
  }
  return out;
}

class AnnouncementBroadcast {
  AnnouncementBroadcast({FirebaseFirestore? db, MemberService? members})
      : _db = db ?? FirebaseFirestore.instance,
        _members = members ?? MemberService();

  final FirebaseFirestore _db;
  final MemberService _members;

  /// The people an announcement should reach.
  ///
  /// Scoped through [MemberService.getMembersInScope] rather than a raw
  /// collection read, because the directory list rule only permits an
  /// unscoped read to head office. The honest consequence: an 'everyone'
  /// announcement written by a parish officer reaches their congregation, not
  /// the organisation — which is why [broadcast] returns a count for the
  /// caller to report instead of claiming success.
  Future<List<Map<String, dynamic>>> resolveRecipients(
    AnnouncementAudience audience, {
    required bool wholeDirectory,
    required String myAtbiyaId,
    String? authorId,
  }) async {
    final members = audience.kind == 'parish'
        ? await _members.getMembersInScope(
            wholeDirectory: false, atbiyaId: audience.atbiyaId)
        : await _members.getMembersInScope(
            wholeDirectory: wholeDirectory, atbiyaId: myAtbiyaId);

    return filterRecipients(members, audience, authorId: authorId);
  }

  /// The sender fields the rule will accept.
  ///
  /// The name is denormalised onto each notification because the recipient
  /// generally cannot read the sender's profile — the directory is scoped and
  /// an ordinary member holds no directory permission. The order here must
  /// stay a subset of what the rule allows, or every send is refused.
  Future<({String senderId, String senderName})> _sender() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw 'Not signed in.';
    var name = '';
    try {
      final snap = await _db.collection('users').doc(uid).get();
      final d = snap.data() ?? {};
      name = (d['fullNameEnglish'] as String?)?.trim().isNotEmpty == true
          ? d['fullNameEnglish'] as String
          : (d['fullName'] as String?)?.trim().isNotEmpty == true
              ? d['fullName'] as String
              : (d['username'] as String?) ?? '';
    } catch (_) {
      // '' is accepted by the rule and renders as no attribution, which beats
      // failing the whole send over a name.
    }
    return (senderId: uid, senderName: name);
  }

  /// Writes one notification per recipient and returns how many landed.
  ///
  /// Batches are committed in sequence rather than in parallel so a large send
  /// degrades gracefully; a failure part-way through leaves the earlier
  /// batches delivered, which is the right trade for an announcement.
  Future<int> broadcast({
    required String title,
    required String content,
    required List<Map<String, dynamic>> recipients,
  }) async {
    if (recipients.isEmpty) return 0;
    final sender = await _sender();
    final createdAt = DateTime.now().toIso8601String();
    final message =
        content.length > 300 ? '${content.substring(0, 300)}…' : content;

    var written = 0;
    for (final group in chunk(recipients)) {
      final batch = _db.batch();
      for (final r in group) {
        batch.set(_db.collection('notifications').doc(), {
          'userId': r['id'],
          'senderId': sender.senderId,
          'senderName': sender.senderName,
          'title': title,
          'message': message,
          'type': 'info',
          'link': '/notifications',
          'status': 'unread',
          'createdAt': createdAt,
        });
      }
      await batch.commit();
      written += group.length;
    }
    return written;
  }
}
