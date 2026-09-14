import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../services/cloudinary_service.dart';
import '../../services/landing_content_service.dart';
import '../../services/localization_service.dart';
import '../../services/news_service.dart';
import '../../theme/app_colors.dart';
import '../branded_loader.dart';
import 'home_common.dart';

/// The homepage news feed — a port of src/components/home/NewsSection.tsx.
///
/// The newest post is a large lead story, the rest a compact list beside it
/// (below it, on a phone). Every string around the posts — heading, badge,
/// description, both button labels, the Head Office / Parish attribution and
/// the empty state — comes from `content.news` in the Landing Editor, as does
/// how many posts to show.
class NewsSection extends StatefulWidget {
  final LandingContent content;
  const NewsSection({super.key, required this.content});

  @override
  State<NewsSection> createState() => _NewsSectionState();
}

class _NewsSectionState extends State<NewsSection> {
  final NewsService _service = NewsService();
  late Stream<List<Map<String, dynamic>>> _stream =
      _service.watchPublished(max: widget.content.newsMaxPosts);
  late int _max = widget.content.newsMaxPosts;

  @override
  void didUpdateWidget(NewsSection old) {
    super.didUpdateWidget(old);
    // The admin can change maxPosts live; re-subscribe when they do.
    if (widget.content.newsMaxPosts != _max) {
      _max = widget.content.newsMaxPosts;
      _stream = _service.watchPublished(max: _max);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.content;
    final loc = Provider.of<LocalizationService>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: homeSectionPadding,
            child: BrandedLoader.inline(),
          );
        }

        final posts = snap.data ?? const <Map<String, dynamic>>[];

        if (posts.isEmpty) {
          return Padding(
            padding: homeSectionPadding,
            child: _EmptyState(
              icon: Icons.newspaper_outlined,
              title: c.newsEmptyTitle,
              description: c.newsEmptyDescription,
            ),
          );
        }

        final lead = posts.first;
        final rest = posts.skip(1).toList();

        return Padding(
          padding: homeSectionPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionBadge(Icons.newspaper_outlined, c.newsBadge),
              const SizedBox(height: 14),
              SectionHeading(c.newsTitle, description: c.newsDescription),
              const SizedBox(height: 24),

              _LeadCard(
                post: lead,
                content: c,
                language: loc.language,
                isDark: isDark,
              ),

              ...rest.asMap().entries.map((e) => _CompactCard(
                    post: e.value,
                    content: c,
                    language: loc.language,
                    isDark: isDark,
                  ).animate().fadeIn(delay: ((e.key + 1) * 80).ms)),

              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PublicNewsListPage(content: c),
                    ),
                  ),
                  style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: EdgeInsets.zero),
                  icon: Text(
                    c.newsSeeAllLabel,
                    style: GoogleFonts.notoSansEthiopic(
                        fontWeight: FontWeight.w900),
                  ),
                  label: const Icon(Icons.arrow_forward, size: 16),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Parish or head-office attribution. The parish name is looked up in the
/// active language — on the web it used to fall back to English for anything
/// that was not Amharic, so Afaan Oromoo and Tigrinya readers always saw
/// English.
String _sourceOf(Map<String, dynamic> post, LandingContent c, String lang) {
  if (post['scope'] != 'atbiya') return c.newsHeadOfficeLabel;
  final names = post['atbiyaName'];
  if (names is Map) {
    for (final key in [lang, 'en']) {
      final v = names[key];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
  }
  return c.newsParishLabel;
}

void _openPost(BuildContext context, Map<String, dynamic> post,
    LandingContent content) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => PublicNewsDetailPage(post: post, content: content),
    ),
  );
}

class _LeadCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final LandingContent content;
  final String language;
  final bool isDark;

  const _LeadCard({
    required this.post,
    required this.content,
    required this.language,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final cover = (post['coverImageUrl'] as String?)?.trim() ?? '';
    final published = formatLandingDate(post['publishedAt'], language);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: homeCardDecoration(isDark, radius: 26),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openPost(context, post, content),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: cover.isEmpty
                    ? Container(
                        color: AppColors.primary.withValues(alpha: 0.05),
                        child: Icon(Icons.newspaper_outlined,
                            size: 48,
                            color: AppColors.primary.withValues(alpha: 0.2)),
                      )
                    : Image.network(
                        CloudinaryService.optimized(cover, width: 1200),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                            color: AppColors.primary.withValues(alpha: 0.05)),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MetaRow(
                      source: _sourceOf(post, content, language),
                      published: published,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      NewsService.pickText(post['title'], language),
                      style: GoogleFonts.notoSansEthiopic(
                        fontSize: 24,
                        height: 1.25,
                        fontWeight: FontWeight.w900,
                        color: homeHeadingColor(isDark),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      NewsService.pickText(post['excerpt'], language),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.notoSansEthiopic(
                        fontSize: 15,
                        height: 1.6,
                        color: homeBodyColor(isDark),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          content.newsReadMoreLabel,
                          style: GoogleFonts.notoSansEthiopic(
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.arrow_forward,
                            size: 16, color: AppColors.primary),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn().moveY(begin: 20);
  }
}

class _CompactCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final LandingContent content;
  final String language;
  final bool isDark;

  const _CompactCard({
    required this.post,
    required this.content,
    required this.language,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final cover = (post['coverImageUrl'] as String?)?.trim() ?? '';
    final published = formatLandingDate(post['publishedAt'], language);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: homeCardDecoration(isDark, radius: 18),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openPost(context, post, content),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 84,
                    height: 84,
                    child: cover.isEmpty
                        ? Container(
                            color: AppColors.primary.withValues(alpha: 0.05),
                            child: Icon(Icons.newspaper_outlined,
                                size: 22,
                                color:
                                    AppColors.primary.withValues(alpha: 0.25)),
                          )
                        : Image.network(
                            CloudinaryService.optimized(cover, width: 300),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                                color:
                                    AppColors.primary.withValues(alpha: 0.05)),
                          ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _MetaRow(
                        source: _sourceOf(post, content, language),
                        published: published,
                        isDark: isDark,
                        dense: true,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        NewsService.pickText(post['title'], language),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.notoSansEthiopic(
                          fontSize: 15,
                          height: 1.35,
                          fontWeight: FontWeight.bold,
                          color: homeHeadingColor(isDark),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final String source;
  final String published;
  final bool isDark;
  final bool dense;

  const _MetaRow({
    required this.source,
    required this.published,
    required this.isDark,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = dense ? 9.0 : 10.0;
    return Wrap(
      spacing: 10,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.church_outlined, size: size + 2, color: AppColors.primary),
            const SizedBox(width: 4),
            Text(
              source.toUpperCase(),
              style: GoogleFonts.notoSansEthiopic(
                fontSize: size,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w900,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        if (published.isNotEmpty)
          Text(
            published.toUpperCase(),
            style: TextStyle(
              fontSize: size,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w900,
              color: homeBodyColor(isDark).withValues(alpha: 0.55),
            ),
          ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: homeCardDecoration(isDark, radius: 26),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, size: 30, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.notoSansEthiopic(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: homeHeadingColor(isDark),
            ),
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSansEthiopic(
                fontSize: 14,
                height: 1.6,
                color: AppColors.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The public archive behind "See all news" — the mobile counterpart of the
/// web's /news route. Reads the same published-only query, so it works while
/// signed out.
class PublicNewsListPage extends StatelessWidget {
  final LandingContent content;
  const PublicNewsListPage({super.key, required this.content});

  @override
  Widget build(BuildContext context) {
    final loc = Provider.of<LocalizationService>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(content.newsTitle,
            style: GoogleFonts.notoSansEthiopic(fontWeight: FontWeight.w900)),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: NewsService().watchPublished(max: 50),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const BrandedLoader(variant: BrandedLoaderVariant.app);
          }
          final posts = snap.data ?? const <Map<String, dynamic>>[];
          if (posts.isEmpty) {
            return Padding(
              padding: homeSectionPadding,
              child: _EmptyState(
                icon: Icons.newspaper_outlined,
                title: content.newsEmptyTitle,
                description: content.newsEmptyDescription,
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(20),
            children: posts
                .map((p) => _CompactCard(
                      post: p,
                      content: content,
                      language: loc.language,
                      isDark: isDark,
                    ))
                .toList(),
          );
        },
      ),
    );
  }
}

/// One post, rendered from the map the feed already read — the mobile
/// counterpart of /news/:slug. No extra Firestore read, and no auth: published
/// posts are public (see the `news` block in firestore.rules).
class PublicNewsDetailPage extends StatelessWidget {
  final Map<String, dynamic> post;
  final LandingContent content;

  const PublicNewsDetailPage({
    super.key,
    required this.post,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    final loc = Provider.of<LocalizationService>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = loc.language;
    final cover = (post['coverImageUrl'] as String?)?.trim() ?? '';

    return Scaffold(
      appBar: AppBar(title: Text(content.newsTitle)),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          if (cover.isNotEmpty)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(
                CloudinaryService.optimized(cover, width: 1400),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MetaRow(
                  source: _sourceOf(post, content, lang),
                  published: formatLandingDate(post['publishedAt'], lang),
                  isDark: isDark,
                ),
                const SizedBox(height: 14),
                Text(
                  NewsService.pickText(post['title'], lang),
                  style: GoogleFonts.notoSansEthiopic(
                    fontSize: 26,
                    height: 1.25,
                    fontWeight: FontWeight.w900,
                    color: homeHeadingColor(isDark),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  NewsService.pickText(post['body'], lang).isNotEmpty
                      ? NewsService.pickText(post['body'], lang)
                      : NewsService.pickText(post['excerpt'], lang),
                  style: GoogleFonts.notoSansEthiopic(
                    fontSize: 16,
                    height: 1.75,
                    color: homeBodyColor(isDark),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
