import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_ahaw/i18n/translations.dart';
import 'package:mobile_ahaw/services/localization_service.dart';

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

  test('fillParams fills the {name} placeholders the catalog ships with', () {
    // The catalog carries entries like `{n} placed` and `{name} will lose
    // access`. Substitution used to be hand-rolled at each call site, so a
    // caller that forgot shipped a literal `{name}` to the screen.
    expect(fillParams('{name} loses access', {'name': 'Abebe'}),
        'Abebe loses access');
    // Every occurrence, not just the first.
    expect(fillParams('{a} and {a}', {'a': 'x'}), 'x and x');
    // A param with no placeholder is ignored; a placeholder with no param
    // survives verbatim rather than becoming an empty gap.
    expect(fillParams('plain', {'nope': 'x'}), 'plain');
    expect(fillParams('{n} placed', const {}), '{n} placed');
    // The catalog entries this guards really do carry placeholders.
    expect(kTranslations['en']!['admin.suspendAccountDesc'], contains('{name}'));
    expect(kTranslations['am']!['admin.suspendAccountDesc'], contains('{name}'));
  });

  test('no dashboard screen gains new hardcoded English', () {
    // A ratchet, not a clean bill of health: these screens still hold raw
    // English and the counts below are today's debt. The test fails if a
    // number goes UP, so a half-migrated screen cannot quietly regress, and
    // it fails if a number goes DOWN so the baseline gets updated rather
    // than drifting out of date.
    const baseline = <String, int>{
    'settings_page.dart': 12,
    'organisation_page.dart': 11,
    'teachings_page.dart': 10,
    'members_page.dart': 7,
    'permission_control_page.dart': 6,
    'mahderat_manager_page.dart': 6,
    'finance_page.dart': 6,
    'reports_page.dart': 4,
    'announcements_page.dart': 4,
    'meetings_page.dart': 3,
    'volunteer_page.dart': 2,
    'notifications_page.dart': 2,
    'plans_page.dart': 1,
    'partner_page.dart': 1,
    'hige_denb_page.dart': 1,
    'church_rules_page.dart': 1,
    };

    final lit = RegExp(r"'((?:\\.|[^'\\\n])*)'");
    final uiContext = RegExp(
        r"(Text\(|label(?:Text)?:\s*|hintText:\s*|title:\s*|content:\s*"
        r"|message:\s*|_textField\([A-Za-z_]+,\s*|_field\([A-Za-z_]+,\s*"
        r"|_showSheet\([A-Za-z_]+,\s*|_empty\(|_snack\(|_action\([A-Za-z_]+,\s*"
        r"|tooltip:\s*|helperText:\s*|errorText:\s*|semanticLabel:\s*)$");
    final englishish = RegExp(r"^[A-Z][A-Za-z0-9 ,'\u2019.?!:\-\u2014\u2026()]*$");

    final counts = <String, int>{};
    final dir = Directory('lib/screens/dashboard_items');
    for (final f in dir.listSync().whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final src = f.readAsStringSync();
      var n = 0;
      for (final m in lit.allMatches(src)) {
        final v = m[1]!;
        if (v.length < 3) continue;
        if (!englishish.hasMatch(v) || !v.contains(RegExp('[a-z]'))) continue;
        if (v.startsWith(RegExp(r'http|assets/|/|#|\{|package:|e\.g'))) continue;
        final pre = src.substring(
            m.start - 60 < 0 ? 0 : m.start - 60, m.start);
        if (pre.trimRight().endsWith('.t(')) continue;
        if (!uiContext.hasMatch(pre)) continue;
        n++;
      }
      if (n > 0) counts[f.uri.pathSegments.last] = n;
    }

    final regressions = <String>[];
    for (final e in counts.entries) {
      final allowed = baseline[e.key] ?? 0;
      if (e.value > allowed) {
        regressions.add('${e.key}: ${e.value} raw strings, baseline $allowed');
      }
    }
    expect(regressions, isEmpty,
        reason: 'new hardcoded English:\n${regressions.join('\n')}');

    final improved = baseline.entries
        .where((e) => (counts[e.key] ?? 0) < e.value)
        .map((e) => '${e.key}: now ${counts[e.key] ?? 0}, baseline ${e.value}')
        .toList();
    expect(improved, isEmpty,
        reason: 'these improved — lower the baseline:\n${improved.join('\n')}');
  });
}
