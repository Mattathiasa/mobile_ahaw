import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

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
  final _service = SuggestionService();
  final _formKey = GlobalKey<FormState>();
  final _messageCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  String _category = 'Appreciation';
  bool _saving = false;
  bool _sent = false;

  static const _categories = {
    'Appreciation': 'Something I appreciate',
    'Change': 'Something to change',
    'Feature': 'Something to add',
    'Problem': 'Something is not working',
  };

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
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Tell Us What You Think',
            style: GoogleFonts.notoSansEthiopic(
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : AppColors.lightText)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back,
              color: isDark ? Colors.white : AppColors.lightText),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _sent ? _thankYou(isDark) : _form(isDark),
    );
  }

  Widget _form(bool isDark) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
              'Something you appreciated, something you would change, something to build — it goes straight to the church office.',
              style: GoogleFonts.notoSansEthiopic(
                  fontSize: 13, color: Colors.grey, height: 1.5)),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            value: _category,
            decoration: const InputDecoration(
                labelText: 'What is this about?',
                border: OutlineInputBorder()),
            items: _categories.entries
                .map((e) =>
                    DropdownMenuItem(value: e.key, child: Text(e.value)))
                .toList(),
            onChanged: (v) => setState(() => _category = v ?? 'Appreciation'),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _messageCtrl,
            maxLines: 5,
            decoration: const InputDecoration(
                labelText: 'Your message', border: OutlineInputBorder()),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Please write a message' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
                labelText: 'Your name (optional)',
                border: OutlineInputBorder()),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _contactCtrl,
            decoration: const InputDecoration(
                labelText: 'Phone or email (optional)',
                border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          Text(
              'Suggestions are read by the church office and are not shown publicly.',
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
              child: Text(_saving ? 'Sending…' : 'Send Suggestion',
                  style: GoogleFonts.notoSansEthiopic(
                      color: Colors.white, fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _thankYou(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.12),
                shape: BoxShape.circle),
            child: const Icon(Icons.check_circle_outline,
                size: 64, color: AppColors.success),
          ),
          const SizedBox(height: 24),
          Text('Thank you',
              style: GoogleFonts.notoSansEthiopic(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : AppColors.lightText)),
          const SizedBox(height: 10),
          Text(
              'Your suggestion has reached the church office. We are grateful you took the time.',
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
            child: const Text('Send another'),
          ),
        ]),
      ),
    );
  }
}
