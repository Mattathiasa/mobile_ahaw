import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../services/signup_service.dart';
import '../services/hierarchy_service.dart';
import '../services/localization_service.dart';
import '../theme/app_colors.dart';

/// Public self-registration. Mirrors the web Signup flow: collect the member's
/// details and requested parish, create a pending account, then return to login.
class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _signup = SignupService();
  final _hierarchy = HierarchyService();
  final _formKey = GlobalKey<FormState>();

  final _nameEnCtrl = TextEditingController();
  final _nameAmCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  String _gender = 'Male';
  String? _atbiyaId;
  String? _atbiyaName;
  bool _saving = false;

  @override
  void dispose() {
    _nameEnCtrl.dispose();
    _nameAmCtrl.dispose();
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_atbiyaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose the parish you want to join.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      if (await _signup.isUsernameTaken(_usernameCtrl.text)) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('That username is already taken.')),
        );
        return;
      }
      await _signup.register(
        fullNameEnglish: _nameEnCtrl.text,
        fullNameAmharic: _nameAmCtrl.text,
        username: _usernameCtrl.text,
        email: _emailCtrl.text,
        password: _passwordCtrl.text,
        phone: _phoneCtrl.text,
        gender: _gender,
        atbiyaId: _atbiyaId!,
        atbiyaName: _atbiyaName ?? '',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Request submitted to $_atbiyaName. You can sign in once an approver activates your account.'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context);
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
    final loc = Provider.of<LocalizationService>(context);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(loc.t('signup').isNotEmpty ? loc.t('signup') : 'Create Account',
            style: GoogleFonts.notoSansEthiopic(
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : AppColors.lightText)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back,
              color: isDark ? Colors.white : AppColors.lightText),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Join the church community',
                style: GoogleFonts.notoSansEthiopic(
                    fontSize: 20, fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : AppColors.lightText)),
            const SizedBox(height: 4),
            Text(
                'Your request is reviewed by an approver at the parish you choose.',
                style: GoogleFonts.notoSansEthiopic(
                    fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 20),
            _field(_nameEnCtrl, 'Full Name (English)', required: true),
            _field(_nameAmCtrl, 'Full Name (Amharic)'),
            _field(_usernameCtrl, 'Username', required: true),
            _field(_emailCtrl, 'Email (optional)',
                keyboardType: TextInputType.emailAddress),
            _field(_phoneCtrl, 'Phone', required: true,
                keyboardType: TextInputType.phone),
            _field(_passwordCtrl, 'Password (min 6)',
                required: true, obscure: true, minLength: 6),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DropdownButtonFormField<String>(
                value: _gender,
                decoration: const InputDecoration(
                    labelText: 'Gender', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'Male', child: Text('Male')),
                  DropdownMenuItem(value: 'Female', child: Text('Female')),
                ],
                onChanged: (v) => setState(() => _gender = v ?? 'Male'),
              ),
            ),
            // Parish selector, from the shared hierarchy (Atbiya level).
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: _hierarchy.getEntitiesByLevel('Atbiya'),
              builder: (context, snapshot) {
                final atbiyas = snapshot.data ?? [];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DropdownButtonFormField<String>(
                    value: _atbiyaId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: atbiyas.isEmpty
                          ? 'Parish (loading…)'
                          : 'Parish you want to join',
                      border: const OutlineInputBorder(),
                    ),
                    items: atbiyas
                        .map((a) => DropdownMenuItem(
                              value: a['id'] as String,
                              child: Text(
                                  (a['name'] ?? a['amharicName'] ?? 'Parish')
                                      .toString()),
                            ))
                        .toList(),
                    onChanged: (v) {
                      setState(() {
                        _atbiyaId = v;
                        _atbiyaName = atbiyas
                            .firstWhere((a) => a['id'] == v,
                                orElse: () => {})['name']
                            ?.toString();
                      });
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14))),
                onPressed: _saving ? null : _submit,
                child: Text(_saving ? 'Submitting…' : 'Submit Request',
                    style: GoogleFonts.notoSansEthiopic(
                        color: Colors.white, fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label,
      {bool required = false,
      bool obscure = false,
      int? minLength,
      TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        obscureText: obscure,
        keyboardType: keyboardType,
        decoration: InputDecoration(
            labelText: label, border: const OutlineInputBorder()),
        validator: (v) {
          if (required && (v == null || v.trim().isEmpty)) return 'Required';
          if (minLength != null && (v ?? '').length < minLength) {
            return 'At least $minLength characters';
          }
          return null;
        },
      ),
    );
  }
}
