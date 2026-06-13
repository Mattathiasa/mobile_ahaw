import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Reads the landing-page content the web admin edits
/// (Site Content Editor → Landing Page Content → siteConfig/landingPage).
/// Multi-language; the mobile home screen renders whatever the admin saved,
/// so web and mobile stay in sync.
class LandingContentService extends ChangeNotifier {
  Map<String, dynamic> _all = {};
  bool _loaded = false;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;

  bool get loaded => _loaded;

  LandingContentService() {
    _sub = FirebaseFirestore.instance
        .collection('siteConfig')
        .doc('landingPage')
        .snapshots()
        .listen((snap) {
      _all = snap.data() ?? {};
      _loaded = true;
      notifyListeners();
    }, onError: (e) {
      if (kDebugMode) print('[LandingContent] listen failed: $e');
      _loaded = true;
      notifyListeners();
    });
  }

  /// Content for a language, falling back to English then {}.
  Map<String, dynamic> forLanguage(String lang) {
    final byLang = _all[lang];
    if (byLang is Map<String, dynamic>) return byLang;
    final en = _all['en'];
    if (en is Map<String, dynamic>) return en;
    return {};
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

/// Typed view over the raw content map, with the same defaults as the web.
class LandingContent {
  final Map<String, dynamic> _d;
  LandingContent(this._d);

  Map<String, dynamic> get _hero => (_d['hero'] as Map<String, dynamic>?) ?? {};
  Map<String, dynamic> get _features => (_d['features'] as Map<String, dynamic>?) ?? {};
  Map<String, dynamic> get _support => (_d['support'] as Map<String, dynamic>?) ?? {};
  Map<String, dynamic> get _footer => (_d['footer'] as Map<String, dynamic>?) ?? {};

  String get heroBadge => _hero['badge'] as String? ?? 'Revolutionizing Ministry';
  String get heroTitle => _hero['title'] as String? ?? 'Mahibere Ahaw';
  String get heroTitleHighlight => _hero['titleHighlight'] as String? ?? '';
  String get heroDescription => _hero['description'] as String? ??
      "A renewed Orthodox Church that serves according to God's will.";
  String get ctaPrimary => _hero['ctaPrimary'] as String? ?? 'Get Started';
  String get ctaSecondary => _hero['ctaSecondary'] as String? ?? 'Learn More';
  String get statsCard1Value => _hero['statsCard1Value'] as String? ?? '';
  String get statsCard1Label => _hero['statsCard1Label'] as String? ?? '';
  String get statsCard2Value => _hero['statsCard2Value'] as String? ?? '';
  String get statsCard2Label => _hero['statsCard2Label'] as String? ?? '';
  /// Optional Cloudinary/remote hero image URL (set in the editor).
  String get heroImageUrl => _hero['imageUrl'] as String? ?? '';

  List<Map<String, dynamic>> get stats {
    final s = _d['stats'];
    if (s is List) return s.whereType<Map<String, dynamic>>().toList();
    return [];
  }

  String get featuresTitle => _features['sectionTitle'] as String? ?? 'Everything You Need';
  String get featuresDescription => _features['sectionDescription'] as String? ?? '';
  List<Map<String, dynamic>> get featureItems {
    final items = _features['items'];
    if (items is List) return items.whereType<Map<String, dynamic>>().toList();
    return [];
  }

  String get supportTitle => _support['title'] as String? ?? 'Support the Ministry';
  String get supportDescription => _support['description'] as String? ?? '';
  String get missionTitle => _support['missionTitle'] as String? ?? 'Our Mission';
  String get missionStatement => _support['missionStatement'] as String? ?? '';
  List<Map<String, dynamic>> get banks {
    final b = _support['banks'];
    if (b is List) return b.whereType<Map<String, dynamic>>().toList();
    return [];
  }

  String get footerDescription => _footer['description'] as String? ?? '';
  String get footerEmail => _footer['email'] as String? ?? '';
  String get footerCopyright => _footer['copyright'] as String? ?? '© 2025 Mahibere Ahaw';
  String get footerYoutube => _footer['youtube'] as String? ?? '';
  String get footerTelegram => _footer['telegram'] as String? ?? '';
  String get footerPhone => _footer['phone'] as String? ?? '';

  List<String> get carousel {
    final c = _d['carousel'];
    if (c is List) return c.whereType<String>().toList();
    return [];
  }

  bool get isEmpty => _d.isEmpty;
}
