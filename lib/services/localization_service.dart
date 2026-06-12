import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../i18n/translations.dart';

/// Shared localization for the app, synced with the web.
///
/// Resolution order for [t]:
///   1. live admin overrides from `siteConfig/pageStrings` (edited in the
///      web admin → Site Content Editor → UI Translations — the same
///      overrides the web pages use, so both apps always show the same text)
///   2. the bundled catalog generated from the web's translations.ts
///   3. English fallback, then the key itself
class LocalizationService extends ChangeNotifier {
  static const supportedLanguages = ['en', 'am', 'om', 'ti'];
  static const languageNames = {
    'en': 'English',
    'am': 'አማርኛ (Amharic)',
    'om': 'Afaan Oromoo',
    'ti': 'ትግርኛ (Tigrigna)',
  };

  String _language = 'en';
  Map<String, dynamic> _overrides = {};
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;

  String get language => _language;

  LocalizationService() {
    _init();
  }

  Future<void> _init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString('app-language');
      if (stored != null && supportedLanguages.contains(stored)) {
        _language = stored;
        notifyListeners();
      }
    } catch (_) {}

    // Live overrides — edits in the web admin appear here within seconds.
    _sub = FirebaseFirestore.instance
        .collection('siteConfig')
        .doc('pageStrings')
        .snapshots()
        .listen((snap) {
      _overrides = snap.data() ?? {};
      notifyListeners();
    }, onError: (e) {
      if (kDebugMode) print('[Localization] overrides listen failed: $e');
    });
  }

  Future<void> setLanguage(String lang) async {
    if (!supportedLanguages.contains(lang) || lang == _language) return;
    _language = lang;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app-language', lang);
    } catch (_) {}
  }

  String t(String key) {
    final langOverrides = _overrides[_language];
    if (langOverrides is Map) {
      final v = langOverrides[key];
      if (v is String && v.isNotEmpty) return v;
    }
    return kTranslations[_language]?[key] ?? kTranslations['en']?[key] ?? key;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
