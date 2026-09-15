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

/// Substitutes `{name}` placeholders in a catalog string.
///
/// Lives outside the service so it can be tested without a Firebase app, and
/// so [AuthErrorKey] and [LocalizationService.t] cannot drift apart.
String fillParams(String value, Map<String, String> params) {
  if (params.isEmpty) return value;
  var out = value;
  params.forEach((k, v) => out = out.replaceAll('{$k}', v));
  return out;
}

///   3. English fallback, then the key itself
class LocalizationService extends ChangeNotifier {
  /// The order the language toggle walks. Amharic sits first after English by
  /// design — matches LANGUAGE_CYCLE in the web's src/i18n/languages.ts.
  static const supportedLanguages = ['en', 'am', 'om', 'ti'];

  /// Each language's endonym — the name it uses for itself.
  ///
  /// A reader looking for their own language scans for "አማርኛ", not for
  /// "Amharic": the English exonym is only legible to someone who already
  /// reads English, which is the wrong assumption for the button that escapes
  /// English. [languageNames] below keeps the parenthetical gloss for the
  /// settings list, where there is room for it.
  /// A 2-character chip label for the nav, where the full endonym does not
  /// fit: 'Afaan Oromoo' alone overflowed a 320dp row by 128px. The endonym
  /// is still what the settings screen and the language sheet show.
  static const languageShortCodes = {
    'en': 'EN',
    'am': 'አማ',
    'om': 'OM',
    'ti': 'ትግ',
  };

  static const languageEndonyms = {
    'en': 'English',
    'am': 'አማርኛ',
    'om': 'Afaan Oromoo',
    'ti': 'ትግርኛ',
  };

  /// The language the toggle moves to next. Wraps around the end of the cycle.
  static String nextLanguageAfter(String current) {
    final i = supportedLanguages.indexOf(current);
    return supportedLanguages[(i + 1) % supportedLanguages.length];
  }

  static const languageNames = {
    'en': 'English',
    'am': 'አማርኛ (Amharic)',
    'om': 'Afaan Oromoo',
    'ti': 'ትግርኛ (Tigrigna)',
  };

  /// Amharic is the church's own language and the language of nearly everyone
  /// who uses this, so a first-time reader lands in it. English remains the
  /// fallback inside [t] for keys with no Amharic string — that is a fallback,
  /// not a preference. Matches DEFAULT_LANGUAGE in the web's
  /// src/contexts/LanguageContext.tsx. A stored preference still wins.
  String _language = 'am';
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
    //
    // `FirebaseFirestore.instance` throws synchronously when there is no
    // Firebase app, and onError only sees stream failures, so this needs its
    // own guard: without one a failed Firebase init takes the whole app down
    // here rather than falling back to the bundled catalog.
    try {
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
    } catch (e) {
      if (kDebugMode) print('[Localization] overrides unavailable: $e');
    }
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

  /// Looks a string up the way the web does.
  ///
  /// The web keys `siteConfig/pageStrings` overrides by dotted path —
  /// `nav.login` — having moved off the bare leaf name (`login`), which
  /// collided whenever two sections shared a key (`nav.plans` vs
  /// `pages.plans`). It still reads the legacy bare form so nothing an admin
  /// already translated is lost; see `lookupOverride` in the web's
  /// src/services/pageStrings.ts.
  ///
  /// So both forms are accepted here, and both are tried against both the
  /// overrides and the bundled catalog. Call sites that predate the dotted
  /// keys pass a bare leaf and keep resolving against the bundled catalog.
  /// [params] fills the `{name}` placeholders the catalog ships with — the
  /// substitution used to be hand-rolled at each call site, which is how
  /// `pinnedCount` could render a literal `{n}` when a caller forgot.
  String t(String key, [Map<String, String> params = const {}]) {
    final leaf = _leafOf(key);

    final langOverrides = _overrides[_language];
    if (langOverrides is Map) {
      for (final k in {key, leaf}) {
        final v = langOverrides[k];
        if (v is String && v.trim().isNotEmpty) return fillParams(v, params);
      }
    }

    for (final lang in {_language, 'en'}) {
      final catalog = kTranslations[lang];
      if (catalog == null) continue;
      for (final k in {key, leaf}) {
        final v = catalog[k];
        if (v != null && v.isNotEmpty) return fillParams(v, params);
      }
    }
    return key;
  }


  /// The leaf name of a dotted path — the legacy key form.
  static String _leafOf(String path) {
    final dot = path.indexOf('.');
    return dot == -1 ? path : path.substring(dot + 1);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
