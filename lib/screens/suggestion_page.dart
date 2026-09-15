import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../services/landing_content_service.dart';
import '../services/suggestion_service.dart';
import '../services/localization_service.dart';
import '../theme/app_colors.dart';

/// The suggestion box — the one place anyone (member or visitor) can write to
/// the church office. Mirrors the web homepage suggestion form.
class SuggestionPage extends StatefulWidget {
  const SuggestionPage({super.key});

  @override
  State<SuggestionPage> createState() => _SuggestionPageState();
}

class _SuggestionPageState extends State<SuggestionPage> {
  LocalizationService get loc =>
      Provider.of<LocalizationService>(context, listen: false);

  final _service = SuggestionService();
  final _formKey = GlobalKey<FormState>();
  final _messageCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  String _category = 'Appreciation';
  bool _saving = false;
  bool _sent = false;

  @override
  void dispose() {
    _messageCtrl.dispose();
    _nameCtrl.dispose();
    _contactCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await _service.submit(
        category: _category,
        message: _messageCtrl.text,
        name: _nameCtrl.text,
        contact: _contactCtrl.text,
        language: Provider.of<LocalizationService>(context, listen: false)
            .language,
      );
      if (mounted) setState(() => _sent = true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(loc.t('errors.suggestionFailed'))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Every label here is admin-editable from the web's Landing Editor. The
    // page used to hardcode its own copies, so an edit made on the web never
    // reached the app.
    final lang = Provider.of<LocalizationService>(context).language;
    final c = LandingContent(
        Provider.of<LandingContentService>(context).forLanguage(lang));

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(c.suggestionsTitle,
            style: GoogleFonts.notoSansEthiopic(
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : AppColors.lightText)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back,
              color: isDark ? Colors.white : AppColors.lightText),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _sent ? _thankYou(isDark, c) : _form(isDark, c),
    );
  }

  Widget _form(bool isDark, LandingContent c) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
              c.suggestionsDescription,
              style: GoogleFonts.notoSansEthiopic(
                  fontSize: 13, color: Colors.grey, height: 1.5)),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: InputDecoration(
                labelText: c.categoryFieldLabel,
                border: const OutlineInputBorder()),
            items: c.suggestionCategories
                .map((e) =>
                    DropdownMenuItem(value: e.token, child: Text(e.label)))
                .toList(),
            onChanged: (v) => setState(() => _category = v ?? 'Appreciation'),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _messageCtrl,
            maxLines: 5,
            decoration: InputDecoration(
                labelText: c.messageFieldLabel,
                hintText: c.messagePlaceholder,
                border: const OutlineInputBorder()),
            maxLength: kSuggestionMaxLength,
            // firestore.rules rejects anything shorter than
            // kSuggestionMinLength, so catching it here is the difference
            // between a clear message and an opaque permission denial.
            validator: (v) => (v ?? '').trim().length < kSuggestionMinLength
                ? loc.t('errors.suggestionTooShort')
                : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _nameCtrl,
            decoration: InputDecoration(
                labelText: c.nameFieldLabel,
                hintText: c.namePlaceholder,
                border: const OutlineInputBorder()),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _contactCtrl,
            decoration: InputDecoration(
                labelText: c.contactFieldLabel,
                hintText: c.contactPlaceholder,
                border: const OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          Text(
              c.suggestionsPrivacyNote,
              style: GoogleFonts.notoSansEthiopic(
                  fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14))),
              onPressed: _saving ? null : _submit,
              child: Text(_saving ? c.submittingLabel : c.submitLabel,
                  style: GoogleFonts.notoSansEthiopic(
                      color: Colors.white, fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _thankYou(bool isDark, LandingContent c) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                shape: BoxShape.circle),
            child: const Icon(Icons.check_circle_outline,
                size: 64, color: AppColors.success),
          ),
          const SizedBox(height: 24),
          Text(c.thankYouTitle,
              style: GoogleFonts.notoSansEthiopic(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : AppColors.lightText)),
          const SizedBox(height: 10),
          Text(
              c.thankYouMessage,
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSansEthiopic(
                  fontSize: 14, color: Colors.grey, height: 1.6)),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () => setState(() {
              _sent = false;
              _saving = false;
              _messageCtrl.clear();
              _nameCtrl.clear();
              _contactCtrl.clear();
            }),
            child: Text(c.sendAnotherLabel),
          ),
        ]),
      ),
    );
  }
}
