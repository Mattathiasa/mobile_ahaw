import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/landing_content_service.dart';
import '../services/localization_service.dart';
import '../widgets/branded_loader.dart';
import '../widgets/home/about_section.dart';
import '../widgets/home/contact_section.dart';
import '../widgets/home/features_section.dart';
import '../widgets/home/gallery_section.dart';
import '../widgets/home/hero_section.dart';
import '../widgets/home/home_footer.dart';
import '../widgets/home/home_nav.dart';
import '../widgets/home/news_section.dart';
import '../widgets/home/sermons_section.dart';
import '../widgets/home/stats_section.dart';
import '../widgets/home/support_section.dart';
import '../widgets/home/suggestion_section.dart';

/// The public landing page — the mobile counterpart of the web homepage
/// (mahibere-ahaw/src/pages/Home.tsx).
///
/// Both clients render the same Firestore documents: `siteConfig/landingPage`
/// for the copy, `siteConfig/gallery` for the photographs, `siteConfig/
/// pageStrings` for the UI strings, plus the public `news` and `teachings`
/// collections. Everything is a live listener or a published-only query, so an
/// edit saved in the web admin reaches a running phone without a restart.
///
/// Section order matches `SECTIONS` in Home.tsx: about sits directly under the
/// hero because who the church is answers the first question a visitor actually
/// has, and suggestions sits last because asking the visitor for something
/// before the page has introduced itself gets a worse answer.
class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  final ScrollController _scrollController = ScrollController();
  bool _scrolled = false;
  String _activeSection = kHomeSections.first;

  /// One key per navigable section, so both the menu and the scroll spy can
  /// find them. Keyed by the same ids the nav uses.
  final Map<String, GlobalKey> _sectionKeys = {
    for (final id in kHomeSections) id: GlobalKey(),
  };

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final scrolled = _scrollController.offset > 50;
    if (scrolled != _scrolled) setState(() => _scrolled = scrolled);
    _updateActiveSection();
  }

  /// Scroll spy: the section whose top is nearest to — but not far below — the
  /// nav bar is the current one. The Flutter equivalent of the
  /// `IntersectionObserver` at Home.tsx:146, with the same intent: a section
  /// only counts as current once it is actually visible below the bar.
  void _updateActiveSection() {
    const navHeight = 96.0;
    String? best;
    double bestTop = double.negativeInfinity;

    for (final entry in _sectionKeys.entries) {
      final ctx = entry.value.currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) continue;
      final top = box.localToGlobal(Offset.zero).dy - navHeight;
      // The topmost section that has already reached the bar wins; ties and
      // sections still below it are ignored.
      if (top <= 0 && top > bestTop) {
        bestTop = top;
        best = entry.key;
      }
    }

    final next = best ?? kHomeSections.first;
    if (next != _activeSection) setState(() => _activeSection = next);
  }

  void _scrollTo(String sectionId) {
    final ctx = _sectionKeys[sectionId]?.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      // Keeps a section's heading clear of the fixed navigation, the same job
      // `scroll-mt-24` does on the web.
      alignment: 0.05,
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<LandingContentService>(context);
    final lang = Provider.of<LocalizationService>(context).language;
    final content = LandingContent(service.forLanguage(lang));

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBodyBehindAppBar: true,
      appBar: HomeNav(
        scrolled: _scrolled,
        activeSection: _activeSection,
        onNavigate: _scrollTo,
      ),
      body: !service.loaded
          ? const BrandedLoader()
          : NotificationListener<ScrollMetricsNotification>(
              // Section geometry is only known after the first layout, so seed
              // the spy once the scroll view reports its metrics.
              onNotification: (_) {
                WidgetsBinding.instance
                    .addPostFrameCallback((_) => _updateActiveSection());
                return false;
              },
              child: SingleChildScrollView(
                controller: _scrollController,
                child: Column(
                  children: [
                    KeyedSubtree(
                      key: _sectionKeys['home'],
                      child: HeroSection(content: content, onAnchor: _scrollTo),
                    ),
                    StatsSection(content: content),
                    const GallerySection(),
                    KeyedSubtree(
                      key: _sectionKeys['about'],
                      child: AboutSection(content: content),
                    ),
                    KeyedSubtree(
                      key: _sectionKeys['services'],
                      child: FeaturesSection(
                          content: content, onAnchor: _scrollTo),
                    ),
                    KeyedSubtree(
                      key: _sectionKeys['support'],
                      child: SupportSection(content: content),
                    ),
                    KeyedSubtree(
                      key: _sectionKeys['news'],
                      child: NewsSection(content: content),
                    ),
                    KeyedSubtree(
                      key: _sectionKeys['sermons'],
                      child: SermonsSection(content: content),
                    ),
                    KeyedSubtree(
                      key: _sectionKeys['contact'],
                      child: ContactSection(content: content),
                    ),
                    KeyedSubtree(
                      key: _sectionKeys['suggestions'],
                      child: SuggestionSection(content: content),
                    ),
                    HomeFooter(content: content, onAnchor: _scrollTo),
                  ],
                ),
              ),
            ),
    );
  }
}
