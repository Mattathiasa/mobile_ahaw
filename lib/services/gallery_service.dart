import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// The home page photo gallery — a port of the web's src/services/gallery.ts.
///
/// Deliberately NOT part of `landingContent`: that document stores a complete
/// copy of the page per language, so photographs would have to be uploaded
/// four times. Only the captions are language-specific, so only the captions
/// are keyed by language.
///
/// Lives in `siteConfig`, which is already public-read and admin-write, so the
/// landing page can read it while signed out.
class GalleryImage {
  final String url;

  /// Cloudinary's identifier for the file. Stored so real deletion stays
  /// possible later without re-uploading everything.
  final String publicId;
  final Map<String, String> caption;

  /// Rotation to apply in the gallery, in degrees clockwise (0/90/180/270).
  /// Useful for photos saved in the wrong orientation.
  final int rotation;

  const GalleryImage({
    required this.url,
    this.publicId = '',
    this.caption = const {},
    this.rotation = 0,
  });

  /// The caption in [lang], falling back to English then anything non-empty.
  String captionFor(String lang) {
    for (final key in [lang, 'en']) {
      final v = caption[key]?.trim();
      if (v != null && v.isNotEmpty) return v;
    }
    for (final v in caption.values) {
      if (v.trim().isNotEmpty) return v.trim();
    }
    return '';
  }
}

class GalleryService extends ChangeNotifier {
  List<GalleryImage> _images = const [];
  bool _loaded = false;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;

  List<GalleryImage> get images => _images;
  bool get loaded => _loaded;

  GalleryService() {
    _sub = FirebaseFirestore.instance
        .collection('siteConfig')
        .doc('gallery')
        .snapshots()
        .listen((snap) {
      _images = _normalize(snap.data());
      _loaded = true;
      notifyListeners();
    }, onError: (e) {
      if (kDebugMode) print('[Gallery] listen failed: $e');
      _loaded = true;
      notifyListeners();
    });
  }

  /// A row with no URL renders as a broken image, so drop it on read rather
  /// than trusting whatever is in the document.
  static List<GalleryImage> _normalize(Map<String, dynamic>? data) {
    final raw = data?['images'];
    if (raw is! List) return const [];
    return raw.whereType<Map>().where((m) {
      final url = m['url'];
      return url is String && url.isNotEmpty;
    }).map((m) {
      final caption = m['caption'];
      return GalleryImage(
        url: m['url'] as String,
        publicId: (m['publicId'] as String?) ?? '',
        caption: caption is Map
            ? {
                for (final e in caption.entries)
                  if (e.value is String) e.key.toString(): e.value as String,
              }
            : const {},
        rotation: (m['rotation'] as num?)?.toInt() ?? 0,
      );
    }).toList();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
