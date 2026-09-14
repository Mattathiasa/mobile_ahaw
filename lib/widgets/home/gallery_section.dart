import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../services/cloudinary_service.dart';
import '../../services/gallery_service.dart';
import '../../services/localization_service.dart';
import '../../theme/app_colors.dart';
import 'home_common.dart';

/// The home page photo gallery — a port of src/components/home/HomeGallery.tsx.
///
/// Photos come from `siteConfig/gallery`, NOT from the landing content
/// document: that one stores a complete copy of the page per language, so the
/// old `carousel` field meant uploading the same photographs four times. Only
/// the captions are language-specific, so only the captions are keyed by
/// language.
///
/// The mobile app read that removed `carousel` field until now, which is why
/// nothing an admin uploaded through the gallery editor ever appeared here.
class GallerySection extends StatefulWidget {
  const GallerySection({super.key});

  @override
  State<GallerySection> createState() => _GallerySectionState();
}

enum _ViewMode { showcase, grid }

class _GallerySectionState extends State<GallerySection> {
  _ViewMode _mode = _ViewMode.grid;
  final PageController _pageController = PageController();
  Timer? _timer;
  int _index = 0;

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  /// Auto-advance every 5s, matching the web — but only in showcase mode, and
  /// never while the lightbox is open (the timer is cancelled on open).
  void _syncTimer(int total) {
    _timer?.cancel();
    if (_mode != _ViewMode.showcase || total < 2) return;
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_pageController.hasClients) return;
      _index = (_index + 1) % total;
      _pageController.animateToPage(
        _index,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    });
  }

  void _setMode(_ViewMode mode, int total) {
    setState(() => _mode = mode);
    _syncTimer(total);
  }

  void _openLightbox(List<GalleryImage> images, int start, String lang) {
    _timer?.cancel();
    Navigator.of(context)
        .push(MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) =>
              _Lightbox(images: images, initialIndex: start, language: lang),
        ))
        .then((_) {
      if (mounted) _syncTimer(images.length);
    });
  }

  @override
  Widget build(BuildContext context) {
    final gallery = Provider.of<GalleryService>(context);
    final images = gallery.images;
    if (images.isEmpty) return const SizedBox.shrink();

    final loc = Provider.of<LocalizationService>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: homeSectionPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionBadge(Icons.photo_library_outlined, loc.t('home.galleryBadge')),
          const SizedBox(height: 14),
          SectionHeading(
            loc.t('home.galleryTitle'),
            description: loc.t('home.galleryDescription'),
          ),
          const SizedBox(height: 20),

          // Showcase / mosaic toggle
          Row(
            children: [
              _ModeChip(
                icon: Icons.view_carousel_outlined,
                label: loc.t('home.galleryShowcase'),
                selected: _mode == _ViewMode.showcase,
                onTap: () => _setMode(_ViewMode.showcase, images.length),
              ),
              const SizedBox(width: 8),
              _ModeChip(
                icon: Icons.grid_view_rounded,
                label: loc.t('home.galleryGrid'),
                selected: _mode == _ViewMode.grid,
                onTap: () => _setMode(_ViewMode.grid, images.length),
              ),
            ],
          ),
          const SizedBox(height: 20),

          if (_mode == _ViewMode.showcase)
            _Showcase(
              images: images,
              controller: _pageController,
              index: _index,
              language: loc.language,
              isDark: isDark,
              counterLabel: loc.t('home.gallerySlideCounter'),
              onPageChanged: (i) => setState(() => _index = i),
              onOpen: (i) => _openLightbox(images, i, loc.language),
            )
          else
            _Mosaic(
              images: images,
              language: loc.language,
              onOpen: (i) => _openLightbox(images, i, loc.language),
            ),
        ],
      ),
    );
  }
}

/// Cloudinary bakes the rotation into the delivery URL, so a client-side
/// rotation is only needed for photos hosted anywhere else. Matches the
/// `rotStyle` guard in HomeGallery.tsx:36.
Widget _photo(GalleryImage image, int width, {BoxFit fit = BoxFit.cover}) {
  final isCloudinary = image.url.contains('/upload/');
  final child = Image.network(
    CloudinaryService.optimized(
      image.url,
      width: width,
      rotation: isCloudinary ? image.rotation : null,
    ),
    fit: fit,
    errorBuilder: (_, __, ___) =>
        Container(color: AppColors.primary.withValues(alpha: 0.08)),
  );

  if (isCloudinary || image.rotation == 0) return child;
  // For 90/270° also shrink slightly so the photo stays inside its box when
  // the axes swap.
  final scale = (image.rotation == 90 || image.rotation == 270) ? 0.75 : 1.0;
  return Transform.rotate(
    angle: image.rotation * 3.1415926535 / 180,
    child: Transform.scale(scale: scale, child: child),
  );
}

class _Showcase extends StatelessWidget {
  final List<GalleryImage> images;
  final PageController controller;
  final int index;
  final String language;
  final bool isDark;
  final String counterLabel;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onOpen;

  const _Showcase({
    required this.images,
    required this.controller,
    required this.index,
    required this.language,
    required this.isDark,
    required this.counterLabel,
    required this.onPageChanged,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final caption = images[index.clamp(0, images.length - 1)].captionFor(language);

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: PageView.builder(
              controller: controller,
              itemCount: images.length,
              onPageChanged: onPageChanged,
              itemBuilder: (context, i) => GestureDetector(
                onTap: () => onOpen(i),
                child: _photo(images[i], 1200),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (caption.isNotEmpty)
          Text(
            caption,
            textAlign: TextAlign.center,
            style: GoogleFonts.notoSansEthiopic(
              fontSize: 13,
              height: 1.5,
              color: homeBodyColor(isDark),
            ),
          ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(images.length, (i) {
            final active = i == index;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              height: 8,
              width: active ? 24 : 8,
              decoration: BoxDecoration(
                color: active
                    ? AppColors.primary
                    : AppColors.primary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Text(
          '$counterLabel ${index + 1} / ${images.length}',
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w900,
            color: AppColors.primary.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}

class _Mosaic extends StatelessWidget {
  final List<GalleryImage> images;
  final String language;
  final ValueChanged<int> onOpen;

  const _Mosaic({
    required this.images,
    required this.language,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: images.length,
      itemBuilder: (context, i) {
        final caption = images[i].captionFor(language);
        return GestureDetector(
          onTap: () => onOpen(i),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _photo(images[i], 600),
                if (caption.isNotEmpty)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(10, 18, 10, 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            AppColors.lightText.withValues(alpha: 0.75),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: Text(
                        caption,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.notoSansEthiopic(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ).animate().fadeIn(delay: (i * 50).ms);
      },
    );
  }
}

/// Full-screen viewer: swipe between photos, pinch to zoom, tap the X to close.
class _Lightbox extends StatefulWidget {
  final List<GalleryImage> images;
  final int initialIndex;
  final String language;

  const _Lightbox({
    required this.images,
    required this.initialIndex,
    required this.language,
  });

  @override
  State<_Lightbox> createState() => _LightboxState();
}

class _LightboxState extends State<_Lightbox> {
  late final PageController _controller =
      PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = Provider.of<LocalizationService>(context);
    final caption = widget.images[_index].captionFor(widget.language);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: widget.images.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) => InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Center(
                  child: _photo(widget.images[i], 2000, fit: BoxFit.contain),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                tooltip: loc.t('home.galleryClose'),
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(20),
                color: Colors.black54,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (caption.isNotEmpty)
                      Text(
                        caption,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.notoSansEthiopic(
                          fontSize: 14,
                          height: 1.5,
                          color: Colors.white,
                        ),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      '${loc.t('home.gallerySlideCounter')} ${_index + 1} / ${widget.images.length}',
                      style: const TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w900,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModeChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 15, color: selected ? Colors.white : AppColors.primary),
            const SizedBox(width: 7),
            Text(
              label,
              style: GoogleFonts.notoSansEthiopic(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: selected ? Colors.white : AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
