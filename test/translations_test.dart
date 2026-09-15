import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_ahaw/i18n/translations.dart';
import 'package:mobile_ahaw/screens/dashboard_items/plans_page.dart';
import 'package:mobile_ahaw/screens/signup_page.dart';
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

  test('every key derived at runtime resolves', () {
    // The key-existence test above scans for literal 'a.b' strings, so keys
    // BUILT from a stored token are invisible to it. A typo in regionKey or
    // ministryKey would ship a literal 'geo.regionX' to the signup form, and
    // nothing else would notice.
    final en = kTranslations['en']!;

    for (final r in kEthiopianRegions) {
      expect(en, contains(regionKey(r)), reason: 'no catalog entry for "$r"');
    }
    for (final m in kMinistryOptions) {
      expect(en, contains(ministryKey(m)), reason: 'no catalog entry for "$m"');
    }
    // Finance and plan tokens map by table rather than by rule; every value
    // in those tables must still name a real entry.
    for (final k in kPlanTokenKeys.values) {
      expect(en, contains(k), reason: 'plan token maps to missing "$k"');
    }
    // Marital status builds its key inline as signup.<lowercased>.
    for (final v in ['Single', 'Married', 'Divorced', 'Widowed']) {
      expect(en, contains('signup.${v.toLowerCase()}'));
    }
  });

  test('no screen gains new hardcoded English', () {
    // A ratchet, not a clean bill of health: these files still hold raw
    // English and the counts are today's debt. The test fails if a number
    // goes UP, so a half-migrated screen cannot quietly regress, and it fails
    // if a number goes DOWN so the baseline is updated rather than drifting.
    //
    // Scope is every screen and widget, not just dashboard_items — an earlier
    // version of this scan looked only at dashboard_items and so reported the
    // dashboard itself, which had zero t() calls, as clean.
    const baseline = <String, int>{
    'main.dart': 2,
    'screens/dashboard_items/church_map_page.dart': 1,
    'screens/dashboard_items/church_rules_page.dart': 4,
    'screens/dashboard_items/documents_page.dart': 3,
    'screens/dashboard_items/finance_page.dart': 36,
    'screens/dashboard_items/hige_denb_page.dart': 10,
    'screens/dashboard_items/hr_page.dart': 14,
    'screens/dashboard_items/inventory_page.dart': 15,
    'screens/dashboard_items/meetings_page.dart': 8,
    'screens/dashboard_items/membership_requests_page.dart': 1,
    'screens/dashboard_items/missionary_page.dart': 6,
    'screens/dashboard_items/my_atbiya_page.dart': 1,
    'screens/dashboard_items/news_page.dart': 4,
    'screens/dashboard_items/notifications_page.dart': 3,
    'screens/dashboard_items/organisation_page.dart': 7,
    'screens/dashboard_items/partner_page.dart': 14,
    'screens/dashboard_items/plans_page.dart': 1,
    'screens/dashboard_items/settings_page.dart': 2,
    'screens/dashboard_items/strategic_plan_page.dart': 8,
    'screens/dashboard_items/user_management_page.dart': 3,
    'screens/dashboard_items/volunteer_page.dart': 10,
    'screens/gate_screens.dart': 3,
    'screens/login_page.dart': 1,
    'screens/signup_page.dart': 21,
    'widgets/branded_loader.dart': 1,
    'widgets/dashboard/dashboard_widgets.dart': 3,
    'widgets/ethiopian_date_picker.dart': 1,
    'widgets/home/contact_section.dart': 4,
    'widgets/home/home_footer.dart': 3,
    'widgets/home/suggestion_section.dart': 2,
    'widgets/image_upload_field.dart': 2,
    'widgets/main_drawer.dart': 2,
    };

    final lit = RegExp(r"'((?:\\.|[^'\\\n])*)'");
    // Contexts where a capitalised literal is data, not display text.
    final deny = RegExp(
        r'(\.collection\(|\.doc\(|\.where\(|\.orderBy\(|\.get\(|'
        r'==\s*$|!=\s*$|case\s*$|contains\(|startsWith\(|endsWith\(|'
        r'\.t\(|\[\s*$|Icons\.|FontAwesomeIcons\.)');
    // Values written to or compared against Firestore, not display text.
    final token = RegExp(
        r'^(Timestamp|Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec'
        r'|Sinodos|KuamiSinodos|Memriya|Zone|Atbiya|EnkesekaseMaikel'
        r'|HiyawanMahderat|Staff|Priest|FullTime|PartTime|New|Good|Fair'
        r'|Poor|Appreciation|Change|Feature|Problem|English|Amharic'
        r'|Published|Draft|Other|Male|Female'
        // permission group identifiers, translated at render
        r'|Pages|Announcements|Plans|Reports|Members|Meetings|Finance'
        r'|Documents|Sermons|Missionary|Dashboard'
        // plan/report timeframe + option tokens
        r'|Weekly|Monthly|Annually|Kifil|Zerf)$');
    final englishish =
        RegExp(r"^[A-Z][A-Za-z0-9 ,'\u2019.?!:\-\u2014&\u2026()@]*$");
    final skipPrefix = RegExp(r'^(http|assets/|/|#|\{|package:)');

    final counts = <String, int>{};
    for (final e in Directory('lib').listSync(recursive: true)) {
      if (e is! File || !e.path.endsWith('.dart')) continue;
      final rel = e.path.substring('lib/'.length);
      if (!rel.startsWith('screens/') &&
          !rel.startsWith('widgets/') &&
          rel != 'main.dart') {
        continue;
      }
      final src = e.readAsStringSync();
      var n = 0;
      for (final m in lit.allMatches(src)) {
        final v = m[1]!;
        if (v.length < 3 || token.hasMatch(v)) continue;
        if (skipPrefix.hasMatch(v)) continue;
        if (!englishish.hasMatch(v)) continue;
        if (!v.contains(RegExp('[a-z]'))) {
          // All-caps display labels count too ('NO MEMBERS YET'); the brand
          // name is not one of them.
          if (v.split(' ').length < 2 || v.startsWith('MAHIBERE AHAW')) continue;
        }
        // A literal immediately followed by ':' is a map key — structure.
        if (m.end < src.length && src[m.end] == ':') continue;
        final pre = src.substring(m.start < 40 ? 0 : m.start - 40, m.start);
        if (deny.hasMatch(pre.trimRight())) continue;
        n++;
      }
      if (n > 0) counts[rel] = n;
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
