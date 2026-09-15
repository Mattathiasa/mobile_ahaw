import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/landing_content_service.dart';
import '../../services/localization_service.dart';
import '../../services/suggestion_service.dart';
import '../../theme/app_colors.dart';
import 'home_common.dart';

/// The homepage suggestion box — a port of
/// src/components/home/SuggestionSection.tsx.
///
/// The one place in this app where somebody with no account writes to the
/// church's database, so read services/suggestion_service.dart and the
/// `suggestions` block in the web repo's firestore.rules together with this.
///
/// Nothing submitted is rendered back. This is a private box, not a comment
/// wall: submissions are read in Software Control and nowhere else, which is
/// why there is no list, no count, and no "recent suggestions" below the form.
///
/// It sits last on the page on purpose: it asks the visitor for something, and
/// asking before the page has said who the church is and how to reach it gets a
/// worse answer than asking after.
class SuggestionSection extends StatefulWidget {
  final LandingContent content;
  const SuggestionSection({super.key, required this.content});

  @override
  State<SuggestionSection> createState() => _SuggestionSectionState();
}

/// Mirrors the caps in the `suggestions` block of firestore.rules. Checked here
/// too so somebody who writes three words is told so in their own language,
/// rather than watching the request come back denied with nothing to explain it.
const int _minMessage = 10;
const int _maxMessage = 2000;
const int _maxName = 80;
const int _maxContact = 120;

/// How long before the same device may send again. Not a security control —
/// preferences are trivially cleared — but it stops the accidental double-send
/// and the idle repeat-clicker, which is most of what a small site actually
/// sees. The real rate limit is App Check.
const Duration _cooldown = Duration(seconds: 60);
const String _cooldownKey = 'suggestion-last-sent';

class _SuggestionSectionState extends State<SuggestionSection> {
  final _service = SuggestionService();
  final _name = TextEditingController();
  final _contact = TextEditingController();
  final _message = TextEditingController();

  /// Honeypot, carried over from the web form. On a native build this catches
  /// nothing — no form-filler walks a Flutter widget tree — but this app also
  /// builds for web, where there is a DOM and where it does its job. Never sent
  /// to Firestore; an extra key would fail the rules' `hasOnly` check anyway.
  final _website = TextEditingController();

  String _category = 'Appreciation';
  bool _sending = false;
  bool _sent = false;
  String? _error;

  LocalizationService get loc =>
      Provider.of<LocalizationService>(context, listen: false);

  @override
  void dispose() {
    _name.dispose();
    _contact.dispose();
    _message.dispose();
    _website.dispose();
    super.dispose();
  }

  Future<bool> _withinCooldown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final last = prefs.getInt(_cooldownKey) ?? 0;
      return DateTime.now().millisecondsSinceEpoch - last <
          _cooldown.inMilliseconds;
    } catch (_) {
      // Somebody who cannot be tracked gets to send — refusing them would be
      // worse than the missed throttle.
      return false;
    }
  }

  Future<void> _markSent() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_cooldownKey, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {/* see _withinCooldown */}
  }

  Future<void> _submit() async {
    if (_sending) return;
    final message = _message.text.trim();

    setState(() => _error = null);

    // Silently accept and discard anything that filled the honeypot: telling a
    // bot it was caught only helps it try again differently.
    if (_website.text.trim().isNotEmpty) {
      setState(() => _sent = true);
      return;
    }

    if (message.length < _minMessage) {
      setState(() => _error = _tooShortMessage());
      return;
    }
    if (await _withinCooldown()) {
      setState(() => _error = _cooldownMessage());
      return;
    }

    setState(() => _sending = true);
    try {
      if (!mounted) return;
      final lang = Provider.of<LocalizationService>(context, listen: false)
          .language;
      await _service.submit(
        category: _category,
        message: message,
        name: _name.text.trim(),
        contact: _contact.text.trim(),
        language: lang,
      );
      await _markSent();
      if (!mounted) return;
      setState(() {
        _sent = true;
        _sending = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        // SuggestionService throws a ready-to-show String for the two failures
        // worth naming separately (anonymous sign-in disabled, generic).
        _error = e is String ? e : _genericFailure();
      });
    }
  }

  String _tooShortMessage() =>
      'Please write at least $_minMessage characters.';
  String _cooldownMessage() =>
      loc.t('errors.suggestionCooldown');
  String _genericFailure() =>
      loc.t('errors.suggestionFailed');

  void _reset() {
    _name.clear();
    _contact.clear();
    _message.clear();
    _website.clear();
    setState(() {
      _sent = false;
      _error = null;
      _category = 'Appreciation';
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.content;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: homeSectionPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionBadge(Icons.lightbulb_outline, c.suggestionsBadge),
          const SizedBox(height: 14),
          SectionHeading(c.suggestionsTitle,
              description: c.suggestionsDescription),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: homeCardDecoration(isDark, radius: 26),
            child: _sent ? _thankYou(c, isDark) : _form(c, isDark),
          ).animate().fadeIn().moveY(begin: 20),
        ],
      ),
    );
  }

  Widget _thankYou(LandingContent c, bool isDark) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_circle_outline,
              size: 32, color: AppColors.success),
        ),
        const SizedBox(height: 16),
        Text(
          c.thankYouTitle,
          textAlign: TextAlign.center,
          style: GoogleFonts.notoSansEthiopic(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: homeHeadingColor(isDark),
          ),
        ),
        if (c.thankYouMessage.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            c.thankYouMessage,
            textAlign: TextAlign.center,
            style: GoogleFonts.notoSansEthiopic(
                fontSize: 14, height: 1.6, color: homeBodyColor(isDark)),
          ),
        ],
        const SizedBox(height: 20),
        OutlinedButton(
          onPressed: _reset,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          ),
          child: Text(
            c.sendAnotherLabel,
            style: GoogleFonts.notoSansEthiopic(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }

  Widget _form(LandingContent c, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(c.categoryFieldLabel),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: c.suggestionCategories.map((cat) {
            final selected = _category == cat.token;
            return ChoiceChip(
              selected: selected,
              // The stored value is the English token; only the label is
              // translated. firestore.rules checks the token.
              onSelected: (_) => setState(() => _category = cat.token),
              label: Text(
                cat.label,
                style: GoogleFonts.notoSansEthiopic(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : AppColors.primary,
                ),
              ),
              showCheckmark: false,
              backgroundColor: AppColors.primary.withValues(alpha: 0.07),
              selectedColor: AppColors.primary,
              side: BorderSide(color: AppColors.primary.withValues(alpha: 0.2)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),

        _FieldLabel(c.nameFieldLabel),
        const SizedBox(height: 8),
        _Field(
          controller: _name,
          hint: c.namePlaceholder,
          maxLength: _maxName,
          isDark: isDark,
        ),
        const SizedBox(height: 16),

        _FieldLabel(c.contactFieldLabel),
        const SizedBox(height: 8),
        _Field(
          controller: _contact,
          hint: c.contactPlaceholder,
          maxLength: _maxContact,
          isDark: isDark,
        ),
        const SizedBox(height: 16),

        _FieldLabel(c.messageFieldLabel),
        const SizedBox(height: 8),
        _Field(
          controller: _message,
          hint: c.messagePlaceholder,
          maxLength: _maxMessage,
          maxLines: 5,
          isDark: isDark,
        ),

        // Honeypot — zero-sized, never focusable by a reader.
        SizedBox(
          height: 0,
          width: 0,
          child: ExcludeSemantics(
            child: Offstage(
              child: TextField(controller: _website),
            ),
          ),
        ),

        if (_error != null) ...[
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.error_outline, size: 18, color: AppColors.error),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _error!,
                  style: GoogleFonts.notoSansEthiopic(
                      fontSize: 13, color: AppColors.error),
                ),
              ),
            ],
          ),
        ],

        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: _sending ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
            ),
            child: _sending
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        c.submittingLabel,
                        style: GoogleFonts.notoSansEthiopic(
                            fontSize: 16, fontWeight: FontWeight.w900),
                      ),
                    ],
                  )
                : Text(
                    c.submitLabel,
                    style: GoogleFonts.notoSansEthiopic(
                        fontSize: 16, fontWeight: FontWeight.w900),
                  ),
          ),
        ),

        if (c.suggestionsPrivacyNote.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            c.suggestionsPrivacyNote,
            style: GoogleFonts.notoSansEthiopic(
              fontSize: 12,
              height: 1.5,
              color: homeBodyColor(isDark).withValues(alpha: 0.7),
            ),
          ),
        ],
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return const SizedBox.shrink();
    return Text(
      text,
      style: GoogleFonts.notoSansEthiopic(
        fontSize: 13,
        fontWeight: FontWeight.w900,
        color: AppColors.primary,
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLength;
  final int maxLines;
  final bool isDark;

  const _Field({
    required this.controller,
    required this.hint,
    required this.maxLength,
    required this.isDark,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLength: maxLength,
      maxLines: maxLines,
      // The counter only earns its space on the long field.
      buildCounter: maxLines > 1
          ? null
          : (_, {required currentLength, required isFocused, maxLength}) => null,
      style: GoogleFonts.notoSansEthiopic(
          fontSize: 15, color: homeHeadingColor(isDark)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.notoSansEthiopic(
          fontSize: 14,
          color: homeBodyColor(isDark).withValues(alpha: 0.6),
        ),
        filled: true,
        fillColor: AppColors.primary.withValues(alpha: 0.05),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide:
              BorderSide(color: AppColors.primary.withValues(alpha: 0.12)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide:
              BorderSide(color: AppColors.primary.withValues(alpha: 0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      ),
    );
  }
}
