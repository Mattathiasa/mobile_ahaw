import 'package:cloud_firestore/cloud_firestore.dart';

/// Public read path for published sermons — a port of `listPublished` and
/// `resolveSermonField` in the web's src/services/sermons.ts.
///
/// Three details carried over deliberately from the web:
///
///  * The collection is still named `teachings`. The feature was renamed to
///    "Sermon" but the storage layer was not, because migrating it risks a
///    silent mismatch with whatever an admin has already configured in
///    Software Control / Module Config / Mobile Control.
///  * The status value is `'Published'` with a capital P — unlike `news`,
///    which uses lowercase `'published'`.
///  * It filters on status ONLY (a single-field equality, so no composite
///    index is required) and sorts + limits on the client, ordering by
///    `createdAt` and falling back to `dateDelivered` for older records.
class SermonsService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _col = 'teachings';

  /// Sortable millisecond value from a Firestore Timestamp or an ISO string.
  static int _sortableTime(dynamic v) {
    if (v == null) return 0;
    if (v is Timestamp) return v.millisecondsSinceEpoch;
    if (v is DateTime) return v.millisecondsSinceEpoch;
    if (v is Map && v['seconds'] is num) {
      return ((v['seconds'] as num) * 1000).toInt();
    }
    if (v is String) return DateTime.tryParse(v)?.millisecondsSinceEpoch ?? 0;
    return 0;
  }

  /// Published sermons, newest first. Readable by anonymous visitors.
  Future<List<Map<String, dynamic>>> listPublished({int max = 4}) async {
    final snap =
        await _db.collection(_col).where('status', isEqualTo: 'Published').get();
    final rows = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    rows.sort((a, b) {
      final bt = _sortableTime(b['createdAt']) != 0
          ? _sortableTime(b['createdAt'])
          : _sortableTime(b['dateDelivered']);
      final at = _sortableTime(a['createdAt']) != 0
          ? _sortableTime(a['createdAt'])
          : _sortableTime(a['dateDelivered']);
      return bt.compareTo(at);
    });
    return rows.length > max ? rows.sublist(0, max) : rows;
  }

  /// Resolves one of a sermon's translatable fields for a language: the
  /// per-language override if one exists and isn't blank, else the base field.
  /// [field] is one of `title`, `shortDescription`, `transcript`.
  static String resolveField(
    Map<String, dynamic>? sermon,
    String field,
    String language,
  ) {
    final translations = sermon?['translations'];
    if (translations is Map) {
      final forLang = translations[language];
      if (forLang is Map) {
        final override = forLang[field];
        if (override is String && override.trim().isNotEmpty) {
          return override.trim();
        }
      }
    }
    final base = sermon?[field];
    return base is String ? base : '';
  }

  /// The date a sermon should show, as millis since epoch, or null.
  static int? timestampOf(Map<String, dynamic> sermon) {
    final t = _sortableTime(sermon['dateDelivered']) != 0
        ? _sortableTime(sermon['dateDelivered'])
        : _sortableTime(sermon['createdAt']);
    return t == 0 ? null : t;
  }
}
