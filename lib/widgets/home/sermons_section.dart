import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../services/cloudinary_service.dart';
import '../../services/landing_content_service.dart';
import '../../services/localization_service.dart';
import '../../services/sermons_service.dart';
import '../../theme/app_colors.dart';
import '../branded_loader.dart';
import 'home_common.dart';

/// The homepage sermons feed — a port of
/// src/components/home/SermonsSection.tsx. Mirrors NewsSection: newest sermon
/// as a lead card, the rest as a compact list, everything around them from
/// `content.teachings` in the Landing Editor.
///
/// Read-only. Everything editable lives on the dashboard Sermons page.
class SermonsSection extends StatefulWidget {
  final LandingContent content;
  const SermonsSection({super.key, required this.content});

  @override
  State<SermonsSection> createState() => _SermonsSectionState();
}

class _SermonsSectionState extends State<SermonsSection> {
  final SermonsService _service = SermonsService();
  late Future<List<Map<String, dynamic>>> _future =
      _service.listPublished(max: widget.content.sermonsMaxPosts);
  late int _max = widget.content.sermonsMaxPosts;

  @override
  void didUpdateWidget(SermonsSection old) {
    super.didUpdateWidget(old);
    if (widget.content.sermonsMaxPosts != _max) {
      _max = widget.content.sermonsMaxPosts;
      _future = _service.listPublished(max: _max);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.content;
    final loc = Provider.of<LocalizationService>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: homeSectionPadding,
            child: BrandedLoader.inline(),
          );
        }

        final items = snap.data ?? const <Map<String, dynamic>>[];

        if (items.isEmpty) {
          return Padding(
            padding: homeSectionPadding,
            child: SermonEmptyState(
              title: c.sermonsEmptyTitle,
              description: c.sermonsEmptyDescription,
            ),
          );
        }

        return Padding(
          padding: homeSectionPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionBadge(Icons.menu_book_outlined, c.sermonsBadge),
              const SizedBox(height: 14),
              SectionHeading(c.sermonsTitle, description: c.sermonsDescription),
              const SizedBox(height: 24),

              _SermonCard(
                sermon: items.first,
                content: c,
                language: loc.language,
                isDark: isDark,
                lead: true,
              ),
              ...items.skip(1).toList().asMap().entries.map((e) => _SermonCard(
                    sermon: e.value,
                    content: c,
                    language: loc.language,
                    isDark: isDark,
                    lead: false,
                  ).animate().fadeIn(delay: ((e.key + 1) * 80).ms)),

              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PublicSermonsListPage(content: c),
                    ),
                  ),
                  style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: EdgeInsets.zero),
                  icon: Text(
                    c.sermonsSeeAllLabel,
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

class _SermonCard extends StatelessWidget {
  final Map<String, dynamic> sermon;
  final LandingContent content;
  final String language;
  final bool isDark;
  final bool lead;

  const _SermonCard({
    required this.sermon,
    required this.content,
    required this.language,
    required this.isDark,
    required this.lead,
  });

  @override
  Widget build(BuildContext context) {
    final image = (sermon['featuredImage'] as String?)?.trim() ?? '';
    final speaker = (sermon['speaker'] as String?)?.trim() ?? '';
    final delivered =
        formatLandingDate(sermon['dateDelivered'], language);
    final title = SermonsService.resolveField(sermon, 'title', language);
    final description =
        SermonsService.resolveField(sermon, 'shortDescription', language);

    void open() => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                PublicSermonDetailPage(sermon: sermon, content: content),
          ),
        );

    if (!lead) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: homeCardDecoration(isDark, radius: 18),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: open,
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
                      child: image.isEmpty
                          ? Container(
                              color: AppColors.primary.withValues(alpha: 0.05),
                              child: Icon(Icons.menu_book_outlined,
                                  size: 22,
                                  color: AppColors.primary
                                      .withValues(alpha: 0.25)),
                            )
                          : Image.network(
                              CloudinaryService.optimized(image, width: 300),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                  color: AppColors.primary
                                      .withValues(alpha: 0.05)),
                            ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SermonMeta(
                            speaker: speaker,
                            delivered: delivered,
                            isDark: isDark,
                            dense: true),
                        const SizedBox(height: 6),
                        Text(
                          title,
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

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: homeCardDecoration(isDark, radius: 26),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: open,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: image.isEmpty
                    ? Container(
                        color: AppColors.primary.withValues(alpha: 0.05),
                        child: Icon(Icons.menu_book_outlined,
                            size: 48,
                            color: AppColors.primary.withValues(alpha: 0.2)),
                      )
                    : Image.network(
                        CloudinaryService.optimized(image, width: 1200),
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
                    _SermonMeta(
                        speaker: speaker, delivered: delivered, isDark: isDark),
                    const SizedBox(height: 12),
                    Text(
                      title,
                      style: GoogleFonts.notoSansEthiopic(
                        fontSize: 24,
                        height: 1.25,
                        fontWeight: FontWeight.w900,
                        color: homeHeadingColor(isDark),
                      ),
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.notoSansEthiopic(
                          fontSize: 15,
                          height: 1.6,
                          color: homeBodyColor(isDark),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          content.sermonsReadMoreLabel,
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

class _SermonMeta extends StatelessWidget {
  final String speaker;
  final String delivered;
  final bool isDark;
  final bool dense;

  const _SermonMeta({
    required this.speaker,
    required this.delivered,
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
        if (speaker.isNotEmpty)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person_outline,
                  size: size + 2, color: AppColors.primary),
              const SizedBox(width: 4),
              Text(
                speaker.toUpperCase(),
                style: GoogleFonts.notoSansEthiopic(
                  fontSize: size,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        if (delivered.isNotEmpty)
          Text(
            delivered.toUpperCase(),
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

/// The editable empty state, shown when nothing is published yet.
class SermonEmptyState extends StatelessWidget {
  final String title;
  final String description;
  const SermonEmptyState(
      {super.key, required this.title, required this.description});

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
            child: const Icon(Icons.menu_book_outlined,
                size: 30, color: AppColors.primary),
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

/// The public archive behind "See all sermons" — mobile's /sermons/browse.
class PublicSermonsListPage extends StatelessWidget {
  final LandingContent content;
  const PublicSermonsListPage({super.key, required this.content});

  @override
  Widget build(BuildContext context) {
    final loc = Provider.of<LocalizationService>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(content.sermonsTitle,
            style: GoogleFonts.notoSansEthiopic(fontWeight: FontWeight.w900)),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: SermonsService().listPublished(max: 50),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const BrandedLoader(variant: BrandedLoaderVariant.app);
          }
          final items = snap.data ?? const <Map<String, dynamic>>[];
          if (items.isEmpty) {
            return Padding(
              padding: homeSectionPadding,
              child: SermonEmptyState(
                title: content.sermonsEmptyTitle,
                description: content.sermonsEmptyDescription,
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(20),
            children: items
                .map((s) => _SermonCard(
                      sermon: s,
                      content: content,
                      language: loc.language,
                      isDark: isDark,
                      lead: false,
                    ))
                .toList(),
          );
        },
      ),
    );
  }
}

/// One sermon — mobile's /sermons/view/:id. Rendered from the map the feed
/// already read; published sermons are public (the `teachings` block in
/// firestore.rules).
class PublicSermonDetailPage extends StatelessWidget {
  final Map<String, dynamic> sermon;
  final LandingContent content;

  const PublicSermonDetailPage({
    super.key,
    required this.sermon,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    final loc = Provider.of<LocalizationService>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = loc.language;
    final image = (sermon['featuredImage'] as String?)?.trim() ?? '';

    // The full text, preferring the long form and falling back through the
    // transcript to the short description.
    final body = [
      (sermon['fullContent'] as String?)?.trim() ?? '',
      SermonsService.resolveField(sermon, 'transcript', lang),
      SermonsService.resolveField(sermon, 'shortDescription', lang),
    ].firstWhere((s) => s.isNotEmpty, orElse: () => '');

    return Scaffold(
      appBar: AppBar(title: Text(content.sermonsTitle)),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          if (image.isNotEmpty)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(
                CloudinaryService.optimized(image, width: 1400),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SermonMeta(
                  speaker: (sermon['speaker'] as String?)?.trim() ?? '',
                  delivered: formatLandingDate(sermon['dateDelivered'], lang),
                  isDark: isDark,
                ),
                const SizedBox(height: 14),
                Text(
                  SermonsService.resolveField(sermon, 'title', lang),
                  style: GoogleFonts.notoSansEthiopic(
                    fontSize: 26,
                    height: 1.25,
                    fontWeight: FontWeight.w900,
                    color: homeHeadingColor(isDark),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  body,
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
