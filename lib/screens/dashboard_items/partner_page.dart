import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_colors.dart';

/// Mirrors the web Partner & Job Contact page: a form that submits to the
/// `partner_contacts` collection.
class PartnerPage extends StatefulWidget {
  const PartnerPage({super.key});

  @override
  State<PartnerPage> createState() => _PartnerPageState();
}

class _PartnerPageState extends State<PartnerPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _messageController = TextEditingController();
  String _type = 'Partnership';
  bool _submitting = false;

  static const _types = {
    'Partnership': 'Partnership (አጋር)',
    'JobApplication': 'Job Application (ስራ መጠየቂያ)',
    'Other': 'Other (ሌላ)',
  };

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    try {
      await FirebaseFirestore.instance.collection('partner_contacts').add({
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'type': _type,
        'message': _messageController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        _formKey.currentState?.reset();
        _nameController.clear();
        _emailController.clear();
        _phoneController.clear();
        _messageController.clear();
        setState(() => _type = 'Partnership');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Request submitted successfully!',
              style: GoogleFonts.notoSansEthiopic()),
          backgroundColor: Colors.green,
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to submit request',
              style: GoogleFonts.notoSansEthiopic()),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
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
        title: Text('Partner & Jobs',
            style: GoogleFonts.notoSansEthiopic(
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : AppColors.lightText,
            )),
        leading: IconButton(
          icon: Icon(Icons.arrow_back,
              color: isDark ? Colors.white : AppColors.lightText),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const FaIcon(FontAwesomeIcons.handshake,
                    color: AppColors.primary, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                'Interested in partnering with us or looking for job opportunities? Fill out the form below.',
                textAlign: TextAlign.center,
                style: GoogleFonts.notoSansEthiopic(
                  fontSize: 12.5,
                  height: 1.6,
                  color: Colors.grey,
                ),
              ),
            ],
          ).animate().fadeIn(),
          const SizedBox(height: 24),
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _label('Full Name'),
                _textField(_nameController, isDark,
                    validator: (v) =>
                        (v ?? '').trim().isEmpty ? 'Name is required' : null),
                const SizedBox(height: 16),
                _label('Interest Type'),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: _boxDecoration(isDark),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _type,
                      isExpanded: true,
                      dropdownColor:
                          isDark ? AppColors.darkSurface : Colors.white,
                      style: GoogleFonts.notoSansEthiopic(
                        fontSize: 13,
                        color: isDark ? Colors.white : AppColors.lightText,
                      ),
                      items: _types.entries
                          .map((e) => DropdownMenuItem(
                              value: e.key, child: Text(e.value)))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _type = v ?? 'Partnership'),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _label('Email'),
                _textField(_emailController, isDark,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      final value = (v ?? '').trim();
                      if (value.isEmpty) return 'Email is required';
                      if (!value.contains('@')) return 'Invalid email';
                      return null;
                    }),
                const SizedBox(height: 16),
                _label('Phone Number'),
                _textField(_phoneController, isDark,
                    keyboardType: TextInputType.phone,
                    validator: (v) =>
                        (v ?? '').trim().isEmpty ? 'Phone is required' : null),
                const SizedBox(height: 16),
                _label('Message / Cover Letter'),
                _textField(_messageController, isDark,
                    maxLines: 5,
                    hint: 'Tell us more about your request...',
                    validator: (v) => (v ?? '').trim().isEmpty
                        ? 'Message is required'
                        : null),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Text('SUBMIT REQUEST',
                            style: GoogleFonts.notoSansEthiopic(
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                              fontSize: 13,
                            )),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text.toUpperCase(),
            style: GoogleFonts.notoSansEthiopic(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
              color: Colors.grey,
            )),
      );

  BoxDecoration _boxDecoration(bool isDark) => BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withOpacity(0.12)),
      );

  Widget _textField(
    TextEditingController controller,
    bool isDark, {
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      style: GoogleFonts.notoSansEthiopic(
        fontSize: 13,
        color: isDark ? Colors.white : AppColors.lightText,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            GoogleFonts.notoSansEthiopic(fontSize: 12, color: Colors.grey),
        filled: true,
        fillColor: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.primary.withOpacity(0.12)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.primary.withOpacity(0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      ),
    );
  }
}
