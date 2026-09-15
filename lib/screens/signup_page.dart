import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../services/hierarchy_service.dart';
import '../services/localization_service.dart';
import '../services/module_config_service.dart';
import '../services/signup_service.dart';
import '../theme/app_colors.dart';
import '../utils/phone.dart';
import '../widgets/brand_mark.dart';
import '../widgets/ethiopian_date_picker.dart';
import 'gate_screens.dart';

/// Self-service membership request — the mobile counterpart of the web's
/// four-step wizard (mahibere-ahaw/src/pages/Signup.tsx).
///
/// It was a single flat form with eight fields, which meant a member who signed
/// up on the phone produced a much thinner record than one who used the web,
/// and an approver saw a half-empty card. The steps, the field set and the
/// validation rules now match.
///
/// What it writes is `users/{uid}` at `status: 'pending'` — there is no
/// separate requests collection; the pending user document *is* the request.
class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

/// The ministries a member can volunteer for, matching MINISTRY_OPTIONS in the
/// web's Signup.tsx. Stored as English tokens.
const List<String> kMinistryOptions = [
  'Sunday School',
  'Youth Ministry',
  'Women Ministry',
  'Choir',
  'Deacon Service',
  'Prayer Team',
  'Media Ministry',
];

/// Catalog key for a stored region token. SNNPR is the one whose key is not
/// a straight camel-case of its name.
String regionKey(String region) => region ==
        'Southern Nations, Nationalities, and Peoples Region'
    ? 'geo.regionSnnpr'
    : 'geo.region${region.split(RegExp(r'[ -]')).map((w) => w[0].toUpperCase() + w.substring(1)).join()}';

/// Catalog key for a stored ministry token.
String ministryKey(String ministry) =>
    'people.ministry${ministry.split(' ').map((w) => w[0].toUpperCase() + w.substring(1)).join()}';

/// Ethiopian regions, from ETHIOPIAN_REGIONS in the web's src/types/index.ts.
const List<String> kEthiopianRegions = [
  'Addis Ababa',
  'Afar',
  'Amhara',
  'Benishangul-Gumuz',
  'Dire Dawa',
  'Gambela',
  'Harari',
  'Oromia',
  'Sidama',
  'Somali',
  'Southern Nations, Nationalities, and Peoples Region',
  'Tigray',
];

class _SignupPageState extends State<SignupPage> {
  final _signup = SignupService();
  final _hierarchy = HierarchyService();

  int _step = 1;
  bool _saving = false;
  String? _error;

  // Step 1
  final _nameEn = TextEditingController();
  final _nameAm = TextEditingController();
  final _phone = TextEditingController();
  String _gender = '';
  String _dateOfBirth = '';

  // Step 2
  final _parishSearch = TextEditingController();
  String? _atbiyaId;
  String? _atbiyaName;

  // Step 3
  final _workSchool = TextEditingController();
  String _maritalStatus = '';
  bool _hasChildren = false;
  final _childrenCount = TextEditingController(text: '0');
  String _region = '';
  final _zone = TextEditingController();
  final _woreda = TextEditingController();
  final Set<String> _ministries = {};

  // Step 4
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();

  @override
  void dispose() {
    for (final c in [
      _nameEn, _nameAm, _phone, _parishSearch, _workSchool,
      _childrenCount, _zone, _woreda, _username, _email,
      _password, _confirmPassword,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Validation — the rules from Signup.tsx:117-145, kept verbatim ──────────

  String? _validateStep(int n, LocalizationService loc) {
    if (n == 1) {
      if (_nameEn.text.trim().isEmpty) return loc.t('signup.errNameEnglish');
      if (_nameAm.text.trim().isEmpty) return loc.t('signup.errNameAmharic');
      if (_phone.text.trim().isEmpty) return loc.t('signup.errPhoneMissing');
      if (!isValidPhone(_phone.text)) return loc.t('signup.errPhoneInvalid');
    }
    if (n == 2 && (_atbiyaId ?? '').isEmpty) {
      return loc.t('signup.errCongregation');
    }
    if (n == 4) {
      final u = _username.text.trim();
      if (u.isEmpty) return loc.t('signup.errUsernameMissing');
      if (!RegExp(r'^[a-zA-Z0-9._-]{3,}$').hasMatch(u)) {
        return loc.t('signup.errUsernameFormat');
      }
      final e = _email.text.trim();
      if (e.isNotEmpty && !RegExp(r'^\S+@\S+\.\S+$').hasMatch(e)) {
        return loc.t('signup.errEmail');
      }
      if (_password.text.length < 6) return loc.t('signup.errPassword');
      if (_password.text != _confirmPassword.text) {
        return loc.t('signup.errPasswordMatch');
      }
    }
    return null;
  }

  void _next(LocalizationService loc) {
    final problem = _validateStep(_step, loc);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _error = null;
      _step = (_step + 1).clamp(1, 4);
    });
  }

  void _back() => setState(() {
        _error = null;
        _step = (_step - 1).clamp(1, 4);
      });

  Future<void> _submit(LocalizationService loc) async {
    // Re-validate every step and jump back to whichever one is at fault, so a
    // problem three steps back cannot be hidden behind a failed write.
    for (var n = 1; n <= 4; n++) {
      final problem = _validateStep(n, loc);
      if (problem != null) {
        setState(() {
          _step = n;
          _error = problem;
        });
        return;
      }
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      if (await _signup.isUsernameTaken(_username.text)) {
        if (!mounted) return;
        setState(() {
          _saving = false;
          _step = 4;
          _error = loc.t('signup.errUsernameTaken');
        });
        return;
      }

      await _signup.register(
        fullNameEnglish: _nameEn.text,
        fullNameAmharic: _nameAm.text,
        username: _username.text,
        email: _email.text,
        password: _password.text,
        phone: _phone.text,
        gender: _gender,
        dateOfBirth: _dateOfBirth,
        atbiyaId: _atbiyaId!,
        atbiyaName: _atbiyaName ?? '',
        maritalStatus: _maritalStatus,
        hasChildren: _hasChildren,
        childrenCount: int.tryParse(_childrenCount.text.trim()) ?? 0,
        workSchool: _workSchool.text,
        region: _region,
        zone: _zone.text,
        woreda: _woreda.text,
        ministryType: _ministries.toList(),
      );

      if (!mounted) return;
      // register() signs the half-authorised session back out, so there is no
      // live user here — show the same holding screen the gate would.
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => PendingApprovalScreen(
          parishName: _atbiyaName,
          onSignOut: () => Navigator.of(context)
              .pushNamedAndRemoveUntil('/', (r) => false),
        ),
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = Provider.of<LocalizationService>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        const Color(0xFF0D2440),
                        const Color(0xFF1A365D),
                        const Color(0xFF0F172A),
                      ]
                    : [
                        const Color(0xFFF0F7FF),
                        const Color(0xFFE0EBF5),
                        const Color(0xFFF8F9FA),
                      ],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _header(context, loc, isDark),
                _stepRail(loc, isDark),
                Expanded(
                  child: ClipRRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                        children: [
                          if (_error != null) _errorBox(_error!),
                          _stepBody(loc, isDark),
                        ],
                      ),
                    ),
                  ),
                ),
                _footer(loc),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(
      BuildContext context, LocalizationService loc, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back),
            color: AppColors.primary,
          ),
          const Spacer(),
          const BrandMark(size: BrandMarkSize.sm),
          const SizedBox(width: 10),
          Text(
            loc.t('signup.title'),
            style: GoogleFonts.notoSansEthiopic(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : AppColors.lightText,
            ),
          ),
          const Spacer(),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  /// The four-circle rail from the web: done steps show a check, the current
  /// one is filled, the rest are muted.
  Widget _stepRail(LocalizationService loc, bool isDark) {
    const icons = [
      Icons.person_outline,
      Icons.church_outlined,
      Icons.work_outline,
      Icons.location_on_outlined,
    ];
    final labels = [
      loc.t('signup.stepDetails'),
      loc.t('signup.stepCongregation'),
      loc.t('signup.stepAbout'),
      loc.t('signup.stepCredentials'),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: List.generate(4, (i) {
          final n = i + 1;
          final done = _step > n;
          final active = _step == n;
          return Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 2,
                        color: i == 0
                            ? Colors.transparent
                            : (done || active
                                ? AppColors.primary
                                : AppColors.primary.withValues(alpha: 0.15)),
                      ),
                    ),
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: done
                            ? AppColors.success
                            : active
                                ? AppColors.primary
                                : AppColors.primary.withValues(alpha: 0.12),
                      ),
                      child: Icon(
                        done ? Icons.check : icons[i],
                        size: 17,
                        color: (done || active)
                            ? Colors.white
                            : AppColors.primary.withValues(alpha: 0.6),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 2,
                        color: i == 3
                            ? Colors.transparent
                            : (done
                                ? AppColors.primary
                                : AppColors.primary.withValues(alpha: 0.15)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.notoSansEthiopic(
                    fontSize: 9,
                    fontWeight: active ? FontWeight.w900 : FontWeight.w600,
                    color: active
                        ? AppColors.primary
                        : (isDark ? Colors.white54 : Colors.black45),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _stepBody(LocalizationService loc, bool isDark) {
    switch (_step) {
      case 1:
        return _StepDetails(
          nameEn: _nameEn,
          nameAm: _nameAm,
          phone: _phone,
          gender: _gender,
          onGender: (g) => setState(() => _gender = g),
          dateOfBirth: _dateOfBirth,
          onDateOfBirth: (d) => setState(() => _dateOfBirth = d),
          loc: loc,
        );
      case 2:
        return _StepCongregation(
          hierarchy: _hierarchy,
          search: _parishSearch,
          selectedId: _atbiyaId,
          onSelect: (id, name) => setState(() {
            _atbiyaId = id;
            _atbiyaName = name;
          }),
          loc: loc,
          isDark: isDark,
        );
      case 3:
        return _StepAbout(
          workSchool: _workSchool,
          maritalStatus: _maritalStatus,
          onMaritalStatus: (v) => setState(() => _maritalStatus = v),
          hasChildren: _hasChildren,
          onHasChildren: (v) => setState(() => _hasChildren = v),
          childrenCount: _childrenCount,
          region: _region,
          onRegion: (v) => setState(() => _region = v),
          zone: _zone,
          woreda: _woreda,
          ministries: _ministries,
          onToggleMinistry: (m) => setState(() {
            _ministries.contains(m)
                ? _ministries.remove(m)
                : _ministries.add(m);
          }),
          loc: loc,
        );
      default:
        return _StepCredentials(
          parishName: _atbiyaName,
          username: _username,
          email: _email,
          password: _password,
          confirmPassword: _confirmPassword,
          loc: loc,
          isDark: isDark,
        );
    }
  }

  Widget _errorBox(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.sacredRed.withValues(alpha: 0.08),
        border:
            Border.all(color: AppColors.sacredRed.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded,
              size: 18, color: AppColors.sacredRed),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.notoSansEthiopic(
                  fontSize: 12, height: 1.5, color: AppColors.sacredRed),
            ),
          ),
        ],
      ),
    ).animate().fadeIn();
  }

  Widget _footer(LocalizationService loc) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Row(
        children: [
          if (_step > 1)
            Expanded(
              child: SizedBox(
                height: 52,
                child: OutlinedButton(
                  onPressed: _saving ? null : _back,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(
                        color: AppColors.primary.withValues(alpha: 0.4)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(loc.t('signup.back'),
                      style: GoogleFonts.notoSansEthiopic(
                          fontWeight: FontWeight.w800)),
                ),
              ),
            ),
          if (_step > 1) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _saving
                    ? null
                    : () => _step == 4 ? _submit(loc) : _next(loc),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        _step == 4
                            ? loc.t('signup.submit')
                            : loc.t('signup.continue'),
                        style: GoogleFonts.notoSansEthiopic(
                            fontSize: 15, fontWeight: FontWeight.w900),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Steps
// ─────────────────────────────────────────────────────────────────────────────

/// Shared field chrome, so all four steps look like one form.
class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool obscure;
  final TextInputType? keyboard;
  const _Field({
    required this.controller,
    required this.label,
    this.hint,
    this.obscure = false,
    this.keyboard,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboard,
        style: GoogleFonts.notoSansEthiopic(fontSize: 15),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          filled: true,
          fillColor: AppColors.primary.withValues(alpha: 0.05),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide:
                BorderSide(color: AppColors.primary.withValues(alpha: 0.12)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide:
                BorderSide(color: AppColors.primary.withValues(alpha: 0.12)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.primary),
          ),
        ),
      ),
    );
  }
}

class _Picker extends StatelessWidget {
  final String label;
  final String value;
  final List<String> options;
  final String Function(String)? labelOf;
  final ValueChanged<String> onChanged;
  const _Picker({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.labelOf,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DropdownButtonFormField<String>(
        initialValue: value.isEmpty ? null : value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: AppColors.primary.withValues(alpha: 0.05),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide:
                BorderSide(color: AppColors.primary.withValues(alpha: 0.12)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide:
                BorderSide(color: AppColors.primary.withValues(alpha: 0.12)),
          ),
        ),
        items: options
            .map((o) => DropdownMenuItem(
                  value: o,
                  child: Text(labelOf?.call(o) ?? o,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.notoSansEthiopic(fontSize: 14)),
                ))
            .toList(),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}

class _StepDetails extends StatelessWidget {
  final TextEditingController nameEn;
  final TextEditingController nameAm;
  final TextEditingController phone;
  final String gender;
  final ValueChanged<String> onGender;
  final String dateOfBirth;
  final ValueChanged<String> onDateOfBirth;
  final LocalizationService loc;

  const _StepDetails({
    required this.nameEn,
    required this.nameAm,
    required this.phone,
    required this.gender,
    required this.onGender,
    required this.dateOfBirth,
    required this.onDateOfBirth,
    required this.loc,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Field(controller: nameEn, label: loc.t('signup.fullNameEnglish')),
        _Field(
            controller: nameAm,
            label: loc.t('signup.fullNameAmharic'),
            hint: 'አበበ ከበደ'),
        _Field(
          controller: phone,
          label: loc.t('signup.phone'),
          hint: '0911 22 33 44',
          keyboard: TextInputType.phone,
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 14, left: 4),
          child: Text(
            loc.t('signup.phoneHint'),
            style: GoogleFonts.notoSansEthiopic(
                fontSize: 11,
                color: AppColors.primary.withValues(alpha: 0.7)),
          ),
        ),
        // Values stay English tokens; only the label is translated.
        _Picker(
          label: loc.t('signup.gender'),
          value: gender,
          options: const ['Male', 'Female'],
          labelOf: (v) =>
              v == 'Male' ? loc.t('signup.male') : loc.t('signup.female'),
          onChanged: onGender,
        ),
        EthiopianDatePicker(
          value: dateOfBirth,
          onChanged: onDateOfBirth,
          label: loc.t('signup.dateOfBirth'),
        ),
      ],
    ).animate().fadeIn().moveX(begin: 16);
  }
}

class _StepCongregation extends StatelessWidget {
  final HierarchyService hierarchy;
  final TextEditingController search;
  final String? selectedId;
  final void Function(String id, String name) onSelect;
  final LocalizationService loc;
  final bool isDark;

  const _StepCongregation({
    required this.hierarchy,
    required this.search,
    required this.selectedId,
    required this.onSelect,
    required this.loc,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Field(
          controller: search,
          label: loc.t('signup.searchCongregations'),
          hint: loc.t('signup.searchPlaceholder'),
        ),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: hierarchy.getEntitiesByLevel('Atbiya'),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primary)),
              );
            }

            // Match the web's getPublicAtbiyas: only parishes that are active
            // and public. Without this the phone offered congregations the web
            // deliberately hides.
            final all = (snap.data ?? [])
                .where((a) => a['active'] != false && a['isPublic'] != false)
                .toList();

            final q = search.text.trim().toLowerCase();
            final list = q.isEmpty
                ? all
                : all.where((a) {
                    final hay = [
                      a['name'],
                      a['nameAmharic'],
                      a['cityEn'],
                      a['cityAm'],
                      (a['address'] is Map) ? a['address']['en'] : null,
                      (a['address'] is Map) ? a['address']['am'] : null,
                    ].whereType<String>().join(' ').toLowerCase();
                    return hay.contains(q);
                  }).toList();

            if (list.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    Text(loc.t('signup.noCongregations'),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.notoSansEthiopic(
                            fontSize: 15, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text(loc.t('signup.noCongregationsHint'),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.notoSansEthiopic(
                            fontSize: 12,
                            color: AppColors.primary
                                .withValues(alpha: 0.7))),
                  ],
                ),
              );
            }

            return Column(
              children: list.map((a) {
                final id = a['id'] as String;
                final name = (a['name'] ?? a['nameAmharic'] ?? '') as String;
                final selected = id == selectedId;
                final place = [a['cityEn'], a['cityAm']]
                    .whereType<String>()
                    .where((s) => s.trim().isNotEmpty)
                    .join(' · ');

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => onSelect(id, name),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.04)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: selected
                              ? AppColors.primary
                              : AppColors.primary.withValues(alpha: 0.12),
                          width: selected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.church_outlined,
                              size: 20,
                              color: AppColors.primary
                                  .withValues(alpha: selected ? 1 : 0.5)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name,
                                    style: GoogleFonts.notoSansEthiopic(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800)),
                                if (place.isNotEmpty)
                                  Text(place,
                                      style: GoogleFonts.notoSansEthiopic(
                                          fontSize: 12,
                                          color: Colors.grey)),
                              ],
                            ),
                          ),
                          if (selected)
                            const Icon(Icons.check_circle,
                                size: 20, color: AppColors.primary),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

class _StepAbout extends StatelessWidget {
  final TextEditingController workSchool;
  final String maritalStatus;
  final ValueChanged<String> onMaritalStatus;
  final bool hasChildren;
  final ValueChanged<bool> onHasChildren;
  final TextEditingController childrenCount;
  final String region;
  final ValueChanged<String> onRegion;
  final TextEditingController zone;
  final TextEditingController woreda;
  final Set<String> ministries;
  final ValueChanged<String> onToggleMinistry;
  final LocalizationService loc;

  const _StepAbout({
    required this.workSchool,
    required this.maritalStatus,
    required this.onMaritalStatus,
    required this.hasChildren,
    required this.onHasChildren,
    required this.childrenCount,
    required this.region,
    required this.onRegion,
    required this.zone,
    required this.woreda,
    required this.ministries,
    required this.onToggleMinistry,
    required this.loc,
  });

  @override
  Widget build(BuildContext context) {
    // Field visibility is admin-controlled per module, exactly as on the web —
    // an admin who hides "workSchool" for members hides it on both clients.
    final cfg = Provider.of<ModuleConfigService>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (cfg.isVisible('members', 'workSchool'))
          _Field(controller: workSchool, label: loc.t('signup.workSchool')),
        if (cfg.isVisible('members', 'maritalStatus'))
          _Picker(
            label: loc.t('signup.maritalStatus'),
            value: maritalStatus,
            options: const ['Single', 'Married', 'Divorced', 'Widowed'],
            labelOf: (v) => loc.t('signup.${v.toLowerCase()}'),
            onChanged: onMaritalStatus,
          ),
        SwitchListTile(
          value: hasChildren,
          onChanged: onHasChildren,
          contentPadding: EdgeInsets.zero,
          title: Text(loc.t('signup.hasChildren'),
              style: GoogleFonts.notoSansEthiopic(fontSize: 14)),
          activeThumbColor: AppColors.primary,
        ),
        if (hasChildren)
          _Field(
            controller: childrenCount,
            label: loc.t('signup.childrenCount'),
            keyboard: TextInputType.number,
          ),
        const SizedBox(height: 6),
        _Picker(
          label: loc.t('signup.region'),
          value: region,
          options: kEthiopianRegions,
          labelOf: (v) => loc.t(regionKey(v)),
          onChanged: onRegion,
        ),
        _Field(controller: zone, label: loc.t('signup.addressZone')),
        _Field(controller: woreda, label: loc.t('signup.addressWoreda')),
        const SizedBox(height: 6),
        Text(loc.t('signup.ministries'),
            style: GoogleFonts.notoSansEthiopic(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: AppColors.primary)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: kMinistryOptions.map((m) {
            final on = ministries.contains(m);
            return FilterChip(
              selected: on,
              onSelected: (_) => onToggleMinistry(m),
              showCheckmark: false,
              label: Text(loc.t(ministryKey(m)),
                  style: GoogleFonts.notoSansEthiopic(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: on ? Colors.white : AppColors.primary)),
              backgroundColor: AppColors.primary.withValues(alpha: 0.07),
              selectedColor: AppColors.primary,
              side: BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.2)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            );
          }).toList(),
        ),
      ],
    ).animate().fadeIn().moveX(begin: 16);
  }
}

class _StepCredentials extends StatelessWidget {
  final String? parishName;
  final TextEditingController username;
  final TextEditingController email;
  final TextEditingController password;
  final TextEditingController confirmPassword;
  final LocalizationService loc;
  final bool isDark;

  const _StepCredentials({
    required this.parishName,
    required this.username,
    required this.email,
    required this.password,
    required this.confirmPassword,
    required this.loc,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if ((parishName ?? '').isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 18),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.church_outlined,
                    size: 20, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(loc.t('signup.requestGoesTo'),
                          style: GoogleFonts.notoSansEthiopic(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.1,
                              color: AppColors.primary)),
                      const SizedBox(height: 3),
                      Text(parishName!,
                          style: GoogleFonts.notoSansEthiopic(
                              fontSize: 15, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        _Field(controller: username, label: loc.t('signup.username')),
        _Field(
          controller: email,
          label: loc.t('signup.email'),
          keyboard: TextInputType.emailAddress,
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 14, left: 4),
          child: Text(
            loc.t('signup.emailHint'),
            style: GoogleFonts.notoSansEthiopic(
                fontSize: 11,
                color: AppColors.primary.withValues(alpha: 0.7)),
          ),
        ),
        _Field(
            controller: password,
            label: loc.t('signup.password'),
            obscure: true),
        _Field(
            controller: confirmPassword,
            label: loc.t('signup.confirmPassword'),
            obscure: true),
      ],
    ).animate().fadeIn().moveX(begin: 16);
  }
}
