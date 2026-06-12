import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../services/localization_service.dart';
import '../../theme/app_colors.dart';

/// Mirrors the web Volunteer page: pick ministry preferences, saved to
/// `users/{uid}.volunteerMinistries`.
class VolunteerPage extends StatefulWidget {
  const VolunteerPage({super.key});

  @override
  State<VolunteerPage> createState() => _VolunteerPageState();
}

class _VolunteerPageState extends State<VolunteerPage> {
  static const _ministries = [
    {
      'id': 'Ebet Metreg',
      'label': 'Ebet Metreg (Cleaning)',
      'description': 'Help keep the church clean and welcoming.',
    },
    {
      'id': 'Natanim Agelgelot',
      'label': 'Natanim Agelgelot',
      'description': 'Special service for helping the needy.',
    },
    {
      'id': 'Choir',
      'label': 'Choir',
      'description': 'Sing in the church choir.',
    },
    {
      'id': 'Ushering',
      'label': 'Ushering',
      'description': 'Welcome and guide guests during services.',
    },
    {
      'id': 'Sunday School',
      'label': 'Sunday School',
      'description': 'Teach and fast-track children.',
    },
    {
      'id': 'Charity',
      'label': 'Charity & Outreach',
      'description': 'Community outreach programs.',
    },
    {
      'id': 'Evangelism',
      'label': 'Evangelism',
      'description': 'Spread the gospel in the community.',
    },
    {
      'id': 'Media',
      'label': 'Media & Tech',
      'description': 'Help with sound, video, and projection.',
    },
  ];

  Set<String> _selected = {};
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadCurrent();
  }

  Future<void> _loadCurrent() async {
    final user = context.read<AuthService>().userModel;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.id)
          .get();
      final list = doc.data()?['volunteerMinistries'];
      if (list is List) {
        _selected = list.whereType<String>().toSet();
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    final user = context.read<AuthService>().userModel;
    if (user == null) return;
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.id).update({
        'volunteerMinistries': _selected.toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Volunteer preferences updated!',
              style: GoogleFonts.notoSansEthiopic()),
          backgroundColor: Colors.green,
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to update preferences',
              style: GoogleFonts.notoSansEthiopic()),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
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
        title: Text(Provider.of<LocalizationService>(context).t('volunteer'),
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
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Verse banner
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.red.withOpacity(0.12)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.favorite, color: Colors.red, size: 28),
                      const SizedBox(height: 10),
                      Text(
                        '"As each has received a gift, use it to serve one another." — 1 Peter 4:10',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.notoSansEthiopic(
                          fontSize: 12.5,
                          height: 1.6,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white70 : Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(),
                const SizedBox(height: 18),
                Text('SELECT YOUR MINISTRY PREFERENCES',
                    style: GoogleFonts.notoSansEthiopic(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                      color: Colors.grey,
                    )),
                const SizedBox(height: 12),
                for (var i = 0; i < _ministries.length; i++)
                  _buildMinistryTile(_ministries[i], isDark, i),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.volunteer_activism, size: 18),
                    label: Text(
                      _saving ? 'SAVING…' : 'SAVE PREFERENCES',
                      style: GoogleFonts.notoSansEthiopic(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildMinistryTile(
      Map<String, String> ministry, bool isDark, int index) {
    final id = ministry['id']!;
    final selected = _selected.contains(id);

    return GestureDetector(
      onTap: () => setState(() {
        if (selected) {
          _selected.remove(id);
        } else {
          _selected.add(id);
        }
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withOpacity(0.07)
              : (isDark ? Colors.white.withOpacity(0.03) : Colors.white),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : AppColors.primary.withOpacity(0.1),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              selected ? Icons.check_box : Icons.check_box_outline_blank,
              color: selected ? AppColors.primary : Colors.grey,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ministry['label']!,
                      style: GoogleFonts.notoSansEthiopic(
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                        color: isDark ? Colors.white : AppColors.lightText,
                      )),
                  const SizedBox(height: 3),
                  Text(ministry['description']!,
                      style: GoogleFonts.notoSansEthiopic(
                        fontSize: 11,
                        color: Colors.grey,
                      )),
                ],
              ),
            ),
          ],
        ),
      ).animate().fadeIn(delay: (index * 60).ms),
    );
  }
}
