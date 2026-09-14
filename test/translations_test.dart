import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_ahaw/i18n/translations.dart';

/// The catalog is bulk-imported from the web's src/i18n/sections/*.ts so both
/// clients say the same thing. These guard the import rather than the wording.
void main() {
  test('carries all four languages', () {
    expect(kTranslations.keys.toSet(), {'en', 'am', 'om', 'ti'});
  });

  test('the imported vocabulary is symmetric between English and Amharic', () {
    // Amharic is the church's own language and the web keeps it complete, so
    // the dotted keys imported from src/i18n/sections must match exactly.
    final en = kTranslations['en']!;
    final am = kTranslations['am']!;
    expect(en.length, greaterThan(2000));

    final importedEn = en.keys.where((k) => k.contains('.'));
    final missing = importedEn.where((k) => !am.containsKey(k)).toList();
    expect(missing, isEmpty,
        reason: 'Amharic is missing ${missing.length} imported keys');
  });

  test('the legacy bare keys are a known, English-only shortfall', () {
    // The original hand-written catalog carried ~154 bare keys with no Amharic
    // translation. They predate the import and are superseded by the dotted
    // equivalents; t() falls back to English for them. Pinned so the number
    // cannot grow — new strings must come from the imported vocabulary.
    final en = kTranslations['en']!;
    final am = kTranslations['am']!;
    final bareOnlyInEnglish =
        en.keys.where((k) => !k.contains('.') && !am.containsKey(k)).length;
    expect(bareOnlyInEnglish, lessThanOrEqualTo(154));
  });

  test('om and ti are partial, and that is deliberate', () {
    // Upstream carries only a subset for these two; English covers the rest.
    for (final lang in ['om', 'ti']) {
      final m = kTranslations[lang]!;
      expect(m, isNotEmpty);
      expect(m.keys.every(kTranslations['en']!.containsKey), isTrue,
          reason: '$lang has keys English does not');
    }
  });

  test('no value is blank — a blank renders as empty UI, not a fallback', () {
    for (final entry in kTranslations.entries) {
      final blank = entry.value.entries.where((e) => e.value.trim().isEmpty);
      expect(blank, isEmpty,
          reason: '${entry.key} has blank values: '
              '${blank.map((e) => e.key).take(5).toList()}');
    }
  });

  test('every key referenced in lib/ exists in the catalog', () {
    // t() returns the key itself on a miss, so an invented key ships as a
    // literal `admin.foo` on screen instead of failing anywhere visible.
    // Interpolated keys (t('nav.\$section')) are skipped — they cannot be
    // resolved statically.
    final en = kTranslations['en']!;
    final referenced = <String>{};
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final src = f.readAsStringSync();
      referenced.addAll(
          RegExp(r"\.t\('([^'\$]+)'\)").allMatches(src).map((m) => m[1]!));
      referenced.addAll(RegExp(
              r"(?:titleKey|messageKey|labelKey|detailKey):\s*'([^'\$]+)'")
          .allMatches(src)
          .map((m) => m[1]!));
    }
    expect(referenced, isNotEmpty);
    final missing = referenced.where((k) => !en.containsKey(k)).toList()..sort();
    expect(missing, isEmpty, reason: 'keys used in code but absent: \$missing');
  });

  test('the sections the dashboard screens need are present', () {
    final en = kTranslations['en']!;
    for (final prefix in [
      'nav.', 'common.', 'pages.', 'admin.', 'forms.', 'status.',
      'people.', 'finance.', 'hr.', 'inventory.', 'modules.',
      'permissions.', 'dashboard.', 'errors.',
    ]) {
      expect(en.keys.any((k) => k.startsWith(prefix)), isTrue,
          reason: 'no keys under "$prefix"');
    }
  });
}
