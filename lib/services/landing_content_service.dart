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
    if (byLang is Map) return Map<String, dynamic>.from(byLang);
    final en = _all['en'];
    if (en is Map) return Map<String, dynamic>.from(en);
    return {};
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

/// A labelled destination in the footer link columns.
/// Mirrors `LandingLink` in the web's src/services/landingContent.ts.
class LandingLink {
  final String label;
  final String url;
  const LandingLink(this.label, this.url);
}

/// What following a configured link should do. Mirrors `resolveLink` in
/// src/services/landingContent.ts:988 — external opens a browser, `#id`
/// scrolls to a section, anything else routes in-app.
enum LinkKind { none, external, anchor, route }

class LinkAction {
  final LinkKind kind;

  /// The external URL, the anchor id, or the in-app route, by [kind].
  final String value;
  const LinkAction(this.kind, this.value);
}

bool _isExternal(String target) =>
    target.startsWith('http://') ||
    target.startsWith('https://') ||
    target.startsWith('mailto:') ||
    target.startsWith('tel:');

/// Resolves a link configured in the Landing Editor. [fallback] is used when
/// the configured URL is blank, matching the web's historic destinations.
LinkAction resolveLink(String? url, {String fallback = ''}) {
  final target = (url ?? '').trim().isNotEmpty ? url!.trim() : fallback.trim();
  if (target.isEmpty) return const LinkAction(LinkKind.none, '');
  if (_isExternal(target)) return LinkAction(LinkKind.external, target);
  if (target.startsWith('#')) {
    return LinkAction(LinkKind.anchor, target.substring(1));
  }
  return LinkAction(LinkKind.route, target);
}

/// Where a feature card's "learn more" goes. Blank resolves to the features
/// page anchored at the card, which is what every card did before the field
/// existed. Mirrors `featureLinkTarget` in the web service.
String featureLinkTarget(Map<String, dynamic> feature) {
  final url = (feature['learnMoreUrl'] as String?)?.trim() ?? '';
  if (url.isNotEmpty) return url;
  final id = (feature['id'] as String?)?.trim() ?? '';
  return id.isEmpty ? '' : '/features#$id';
}

/// Typed view over the raw content map, with the same defaults as the web
/// (`DEFAULT_LANDING_CONTENT.en` in src/services/landingContent.ts).
class LandingContent {
  final Map<String, dynamic> _d;
  LandingContent(this._d);

  // ── Readers ────────────────────────────────────────────────────────────────
  // Firestore hands back Map<String, dynamic> / List<dynamic>; a document
  // written by an older build may be missing a block entirely, so every read
  // goes through one of these rather than a raw cast.

  static Map<String, dynamic> _mapOf(Map<String, dynamic> src, String key) {
    final v = src[key];
    return v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
  }

  static String _str(Map<String, dynamic> src, String key, [String fallback = '']) {
    final v = src[key];
    return v is String && v.isNotEmpty ? v : fallback;
  }

  static List<Map<String, dynamic>> _maps(Map<String, dynamic> src, String key) {
    final v = src[key];
    if (v is! List) return const [];
    return v
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
  }

  static List<String> _strings(
    Map<String, dynamic> src,
    String key, [
    List<String> fallback = const [],
  ]) {
    final v = src[key];
    if (v is! List) return fallback;
    final out = v.whereType<String>().where((s) => s.trim().isNotEmpty).toList();
    return out.isEmpty ? fallback : out;
  }

  static List<LandingLink> _links(Map<String, dynamic> src, String key) =>
      _maps(src, key)
          .map((m) => LandingLink(
                (m['label'] as String?)?.trim() ?? '',
                (m['url'] as String?)?.trim() ?? '',
              ))
          .where((l) => l.label.isNotEmpty)
          .toList();

  Map<String, dynamic> get _hero => _mapOf(_d, 'hero');
  Map<String, dynamic> get _features => _mapOf(_d, 'features');
  Map<String, dynamic> get _support => _mapOf(_d, 'support');
  Map<String, dynamic> get _footer => _mapOf(_d, 'footer');
  Map<String, dynamic> get _about => _mapOf(_d, 'about');
  Map<String, dynamic> get _contact => _mapOf(_d, 'contact');
  Map<String, dynamic> get _news => _mapOf(_d, 'news');
  Map<String, dynamic> get _teachings => _mapOf(_d, 'teachings');
  Map<String, dynamic> get _suggestions => _mapOf(_d, 'suggestions');

  bool get isEmpty => _d.isEmpty;

  // ── Hero ───────────────────────────────────────────────────────────────────

  String get heroBadge => _str(_hero, 'badge', 'Revolutionizing Ministry');
  String get heroTitle => _str(_hero, 'title', 'Mahibere Ahaw');
  String get heroTitleHighlight => _str(_hero, 'titleHighlight');
  String get heroDescription => _str(_hero, 'description',
      "A renewed Orthodox Church that serves according to God's will.");
  String get ctaPrimary => _str(_hero, 'ctaPrimary', 'Get Started');
  String get ctaSecondary => _str(_hero, 'ctaSecondary', 'Learn More');
  String get ctaPrimaryUrl => _str(_hero, 'ctaPrimaryUrl');
  String get ctaSecondaryUrl => _str(_hero, 'ctaSecondaryUrl');

  /// Optional Cloudinary/remote hero image URL (set in the editor).
  String get heroImageUrl => _str(_hero, 'imageUrl');

  // ── Stats ──────────────────────────────────────────────────────────────────

  List<Map<String, dynamic>> get stats => _maps(_d, 'stats');

  // ── Features ───────────────────────────────────────────────────────────────

  String get featuresTitle =>
      _str(_features, 'sectionTitle', 'Everything You Need');
  String get featuresDescription => _str(_features, 'sectionDescription');
  List<Map<String, dynamic>> get featureItems => _maps(_features, 'items');

  // ── About ──────────────────────────────────────────────────────────────────

  String get aboutBadge => _str(_about, 'badge', 'About Us');
  String get aboutTitle =>
      _str(_about, 'sectionTitle', 'About Us & Our Faith');
  String get aboutDescription => _str(_about, 'sectionDescription');
  String get whoWeAreTitle => _str(_about, 'whoWeAreTitle', 'Our Origin');
  String get whoWeAreDescription => _str(_about, 'whoWeAreDescription');

  /// Sends the reader to the full history. Blank hides the button.
  String get historyLinkLabel => _str(_about, 'historyLinkLabel');
  String get historyUrl => _str(_about, 'historyUrl');

  String get aboutMissionTitle => _str(_about, 'missionTitle', 'Our Mission');
  String get aboutMissionDescription => _str(_about, 'missionDescription');
  String get visionTitle => _str(_about, 'visionTitle', 'Our Vision');
  String get visionDescription => _str(_about, 'visionDescription');

  String get beliefsEyebrow => _str(_about, 'beliefsEyebrow');
  String get beliefsTitle => _str(_about, 'beliefsTitle', 'What We Believe');
  List<Map<String, dynamic>> get beliefs => _maps(_about, 'beliefs');

  String get valuesEyebrow => _str(_about, 'valuesEyebrow');
  String get valuesTitle => _str(_about, 'valuesTitle', 'Our Values');
  List<Map<String, dynamic>> get values => _maps(_about, 'values');

  /// The mission is a list of commitments when the admin wrote several lines,
  /// and a paragraph when they wrote one. Matches Home.tsx:449.
  List<String> get aboutMissionLines => aboutMissionDescription
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();

  // ── Support ────────────────────────────────────────────────────────────────

  String get supportBadge => _str(_support, 'badge', 'Ministerial Support');
  String get supportTitle => _str(_support, 'title', 'Support the Ministry');
  String get supportDescription => _str(_support, 'description');
  String get missionTitle => _str(_support, 'missionTitle', 'Our Mission');
  String get missionStatement => _str(_support, 'missionStatement');
  List<Map<String, dynamic>> get banks => _maps(_support, 'banks');

  // ── Contact ────────────────────────────────────────────────────────────────

  String get contactBadge => _str(_contact, 'badge', 'Get in Touch');
  String get contactTitle => _str(_contact, 'sectionTitle', 'Contact Us');
  String get contactDescription => _str(_contact, 'sectionDescription');
  String get addressLabel => _str(_contact, 'addressLabel', 'Address');
  String get address => _str(_contact, 'address');
  String get phoneLabel => _str(_contact, 'phoneLabel', 'Phone');
  List<String> get phones => _strings(_contact, 'phones');
  String get emailLabel => _str(_contact, 'emailLabel', 'Email');
  List<String> get emails => _strings(_contact, 'emails');
  String get hoursLabel => _str(_contact, 'hoursLabel', 'Office Hours');
  String get hours => _str(_contact, 'hours');
  String get mapUrl => _str(_contact, 'mapUrl');
  String get socialsLabel => _str(_contact, 'socialsLabel', 'Follow Us');
  String get contactYoutube => _str(_contact, 'youtube');
  String get contactTelegram => _str(_contact, 'telegram');
  String get contactFacebook => _str(_contact, 'facebook');
  String get contactTiktok => _str(_contact, 'tiktok');
  String get contactWebsite => _str(_contact, 'website');

  /// The public site, always resolvable.
  ///
  /// Prefers whatever an admin typed into the Landing Editor's contact block so
  /// the address can change without a new build, and falls back to the domain
  /// in the web repo's CNAME. Both social rows render this rather than
  /// `contactWebsite` directly — otherwise the link simply vanished whenever
  /// the field happened to be blank in Firestore.
  String get websiteUrl {
    final configured = contactWebsite.trim();
    if (configured.isEmpty) return kPublicWebsiteUrl;
    return configured.startsWith('http')
        ? configured
        : 'https://$configured';
  }

  // ── News ───────────────────────────────────────────────────────────────────

  String get newsBadge => _str(_news, 'badge', 'Latest');
  String get newsTitle => _str(_news, 'sectionTitle', 'News & Updates');
  String get newsDescription => _str(_news, 'sectionDescription');
  String get newsSeeAllLabel => _str(_news, 'seeAllLabel', 'See all news');
  String get newsReadMoreLabel => _str(_news, 'readMoreLabel', 'Read more');
  String get newsHeadOfficeLabel =>
      _str(_news, 'headOfficeLabel', 'Head Office');
  String get newsParishLabel =>
      _str(_news, 'parishLabel', 'Local Congregation');
  String get newsEmptyTitle => _str(_news, 'emptyTitle', 'News & Updates');
  String get newsEmptyDescription => _str(_news, 'emptyDescription');
  int get newsMaxPosts => (_news['maxPosts'] as num?)?.toInt() ?? 4;

  // ── Sermons ────────────────────────────────────────────────────────────────
  // Stored under `teachings` — the field name was kept when the feature was
  // renamed, exactly as in src/services/sermons.ts.

  String get sermonsBadge => _str(_teachings, 'badge', 'Sermons');
  String get sermonsTitle => _str(_teachings, 'sectionTitle', 'Sermons');
  String get sermonsDescription => _str(_teachings, 'sectionDescription');
  String get sermonsSeeAllLabel =>
      _str(_teachings, 'seeAllLabel', 'See all sermons');
  String get sermonsReadMoreLabel =>
      _str(_teachings, 'readMoreLabel', 'Read more');
  String get sermonsEmptyTitle => _str(_teachings, 'emptyTitle', 'Sermons');
  String get sermonsEmptyDescription => _str(_teachings, 'emptyDescription');
  int get sermonsMaxPosts => (_teachings['maxPosts'] as num?)?.toInt() ?? 4;

  // ── Suggestions ────────────────────────────────────────────────────────────

  String get suggestionsBadge => _str(_suggestions, 'badge', 'Your Voice');
  String get suggestionsTitle =>
      _str(_suggestions, 'sectionTitle', 'Tell Us What You Think');
  String get suggestionsDescription => _str(_suggestions, 'sectionDescription',
      'Something you appreciated, something you would change, something you '
      'would like us to build — write it here. It goes straight to the church '
      'office.');
  String get categoryFieldLabel =>
      _str(_suggestions, 'categoryFieldLabel', 'What is this about?');
  String get nameFieldLabel =>
      _str(_suggestions, 'nameFieldLabel', 'Your name (optional)');
  String get namePlaceholder =>
      _str(_suggestions, 'namePlaceholder', 'Leave blank to stay anonymous');
  String get contactFieldLabel =>
      _str(_suggestions, 'contactFieldLabel', 'Phone or email (optional)');
  String get contactPlaceholder => _str(
      _suggestions, 'contactPlaceholder', 'Only if you would like a reply');
  String get messageFieldLabel =>
      _str(_suggestions, 'messageFieldLabel', 'Your message');
  String get messagePlaceholder => _str(_suggestions, 'messagePlaceholder',
      'Write as much or as little as you like.');
  String get suggestionsPrivacyNote => _str(_suggestions, 'privacyNote',
      'Suggestions are read by the church office and are not shown publicly '
      'on this page.');
  String get submitLabel => _str(_suggestions, 'submitLabel', 'Send suggestion');
  String get submittingLabel => _str(_suggestions, 'submittingLabel', 'Sending…');
  String get thankYouTitle => _str(_suggestions, 'thankYouTitle', 'Thank you');
  String get thankYouMessage => _str(_suggestions, 'thankYouMessage',
      'Your suggestion has reached the church office. We are grateful you '
      'took the time.');
  String get sendAnotherLabel =>
      _str(_suggestions, 'sendAnotherLabel', 'Send another');

  /// The four choices in the order the web renders them. The label is
  /// translated; the `token` is the English value stored in Firestore and
  /// checked by firestore.rules, and must never be localized.
  List<({String token, String label})> get suggestionCategories => [
        (
          token: 'Appreciation',
          label: _str(_suggestions, 'categoryAppreciationLabel',
              'Something I appreciate')
        ),
        (
          token: 'Change',
          label: _str(
              _suggestions, 'categoryChangeLabel', 'Something to change')
        ),
        (
          token: 'Feature',
          label:
              _str(_suggestions, 'categoryFeatureLabel', 'Something to add')
        ),
        (
          token: 'Problem',
          label: _str(_suggestions, 'categoryProblemLabel',
              'Something is not working')
        ),
      ];

  // ── Footer ─────────────────────────────────────────────────────────────────

  String get footerDescription => _str(_footer, 'description');
  String get footerEmail => _str(_footer, 'email');
  String get footerCopyright =>
      _str(_footer, 'copyright', '© 2025 Mahibere Ahaw');
  String get footerYoutube => _str(_footer, 'youtube');
  String get footerTelegram => _str(_footer, 'telegram');
  String get footerFacebook => _str(_footer, 'facebook');
  String get footerPhone => _str(_footer, 'phone');

  String get platformHeading => _str(_footer, 'platformHeading', 'Platform');
  List<LandingLink> get platformLinks => _links(_footer, 'platformLinks');
  String get supportHeading => _str(_footer, 'supportHeading', 'Support');
  List<LandingLink> get supportLinks => _links(_footer, 'supportLinks');

  String get privacyLabel => _str(_footer, 'privacyLabel');
  String get privacyUrl => _str(_footer, 'privacyUrl');
  String get termsLabel => _str(_footer, 'termsLabel');
  String get termsUrl => _str(_footer, 'termsUrl');
}

/// The church's public site.
///
/// Taken from the web repo's CNAME (`mahibere-ahaw/CNAME`). Used only as a
/// fallback: `contact.website` in the Landing Editor wins when an admin has
/// set it, so the address can change without shipping a new build.
const String kPublicWebsiteUrl = 'https://mahibereahaw.org.et';
