import 'package:cloud_firestore/cloud_firestore.dart';

/// Homepage news / blog, mirroring the web's src/services/news.ts. The document
/// id IS the slug. Text fields are localized maps ({en, am, ...}).
class NewsService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _col = 'news';

  /// First non-empty string, preferring [lang] then English then Amharic.
  static String pickText(dynamic text, String lang) {
    if (text is! Map) return '';
    final ordered = [text[lang], text['en'], text['am']];
    for (final v in ordered) {
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    for (final v in text.values) {
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    return '';
  }

  static String slugify(String title) {
    var base = title
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .trim()
        .replaceAll(RegExp(r'[\s_-]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    if (base.length > 60) base = base.substring(0, 60);
    return base.isEmpty ? 'post-${DateTime.now().millisecondsSinceEpoch}' : base;
  }

  Stream<List<Map<String, dynamic>>> watchPublished({int max = 24}) {
    return _db
        .collection(_col)
        .where('status', isEqualTo: 'published')
        .orderBy('publishedAt', descending: true)
        .limit(max)
        .snapshots()
        .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  /// Everything an author may manage — their parish's posts, or all posts for a
  /// head-office author. Sorted client-side so drafts need no index.
  Future<List<Map<String, dynamic>>> listForAuthor({
    required bool isHeadOffice,
    String? atbiyaId,
  }) async {
    final snap = (isHeadOffice || atbiyaId == null || atbiyaId.isEmpty)
        ? await _db.collection(_col).get()
        : await _db.collection(_col).where('atbiyaId', isEqualTo: atbiyaId).get();
    final list = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    list.sort((a, b) => (b['updatedAt'] ?? b['createdAt'] ?? '')
        .toString()
        .compareTo((a['updatedAt'] ?? a['createdAt'] ?? '').toString()));
    return list;
  }

  Future<String> _uniqueSlug(String title) async {
    final base = slugify(title);
    for (var i = 0; i < 25; i++) {
      final candidate = i == 0 ? base : '$base-${i + 1}';
      final existing = await _db.collection(_col).doc(candidate).get();
      if (!existing.exists) return candidate;
    }
    return '$base-${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<String> create(Map<String, dynamic> input) async {
    final title = input['title'];
    final seed = pickText(title, 'en').isNotEmpty
        ? pickText(title, 'en')
        : pickText(title, 'am');
    final slug = await _uniqueSlug(seed);
    final now = DateTime.now().toIso8601String();
    final payload = {
      ...input,
      'slug': slug,
      'publishedAt': input['status'] == 'published' ? now : null,
      'createdAt': now,
      'updatedAt': now,
    };
    await _db.collection(_col).doc(slug).set(payload);
    return slug;
  }

  Future<void> update(String id, Map<String, dynamic> input) async {
    final patch = {...input, 'updatedAt': DateTime.now().toIso8601String()};
    patch.remove('slug'); // frozen after creation so links never break
    await _db.collection(_col).doc(id).update(patch);
  }

  Future<void> setStatus(String id, String status) async {
    await _db.collection(_col).doc(id).update({
      'status': status,
      if (status == 'published')
        'publishedAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> remove(String id) => _db.collection(_col).doc(id).delete();
}
