import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_colors.dart';

/// Mirrors the web Church Rules (ChurchLaws) page: tabbed canonical law —
/// General Guidelines, Prohibitions, Obligations, and Admin Rules.
class ChurchRulesPage extends StatelessWidget {
  const ChurchRulesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor:
            isDark ? AppColors.darkBackground : AppColors.lightBackground,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text('Church Rules',
              style: GoogleFonts.notoSansEthiopic(
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : AppColors.lightText,
              )),
          leading: IconButton(
            icon: Icon(Icons.arrow_back,
                color: isDark ? Colors.white : AppColors.lightText),
            onPressed: () => Navigator.pop(context),
          ),
          bottom: TabBar(
            isScrollable: true,
            labelColor: AppColors.primary,
            unselectedLabelColor: Colors.grey,
            indicatorColor: AppColors.primary,
            labelStyle: GoogleFonts.notoSansEthiopic(
                fontWeight: FontWeight.w900, fontSize: 12),
            tabs: const [
              Tab(text: 'Guidelines'),
              Tab(text: 'Prohibitions'),
              Tab(text: 'Obligations'),
              Tab(text: 'Admin Rules'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _guidelinesTab(isDark),
            _prohibitionsTab(isDark),
            _obligationsTab(isDark),
            _adminTab(isDark),
          ],
        ),
      ),
    );
  }

  // ── Guidelines ──────────────────────────────────────────────────────────

  Widget _guidelinesTab(bool isDark) {
    const items = [
      {
        'title': '1. Sunday Worship',
        'desc':
            'All members are expected to attend Sunday worship services regularly with devotion and humility.',
        'icon': FontAwesomeIcons.wandMagicSparkles,
      },
      {
        'title': '2. Community Service',
        'desc':
            'Members are encouraged to participate in at least one community service activity per month to manifest the love of Christ in action.',
        'icon': FontAwesomeIcons.heart,
      },
      {
        'title': '3. Spiritual Growth',
        'desc':
            'Active participation in Bible studies, fasting periods, and sacraments is vital for the spiritual maturity of every believer.',
        'icon': FontAwesomeIcons.shieldHeart,
      },
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: items.length,
      itemBuilder: (context, i) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.primary.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                FaIcon(items[i]['icon'] as IconData,
                    size: 16, color: AppColors.primary.withOpacity(0.6)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(items[i]['title'] as String,
                      style: GoogleFonts.notoSansEthiopic(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: isDark ? Colors.white : AppColors.lightText,
                      )),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(items[i]['desc'] as String,
                style: GoogleFonts.notoSansEthiopic(
                  fontSize: 12.5,
                  height: 1.7,
                  fontStyle: FontStyle.italic,
                  color: isDark ? Colors.white60 : Colors.grey.shade700,
                )),
          ],
        ),
      ).animate().fadeIn(delay: (i * 100).ms).slideY(begin: 0.05),
    );
  }

  // ── Prohibitions ────────────────────────────────────────────────────────

  Widget _prohibitionsTab(bool isDark) {
    const rules = [
      'Disruptive behavior during services that hinders the spiritual peace of the congregation.',
      'Misuse or mishandling of church funds, property, or sacred items.',
      'Public defamation, gossip, or causing division among church leadership or members.',
      'Non-compliance with the established canonical practices and traditions.',
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: rules.length,
      itemBuilder: (context, i) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.05),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.red.withOpacity(0.12)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 6),
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(rules[i],
                  style: GoogleFonts.notoSansEthiopic(
                    fontSize: 13,
                    height: 1.6,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white70 : AppColors.lightText,
                  )),
            ),
          ],
        ),
      ).animate().fadeIn(delay: (i * 100).ms).slideY(begin: 0.05),
    );
  }

  // ── Obligations ─────────────────────────────────────────────────────────

  Widget _obligationsTab(bool isDark) {
    const items = [
      {
        'title': 'Tithe (Asrat)',
        'desc':
            'Faithful and regular contribution of the tithe for church operations.',
      },
      {
        'title': 'Mahderat',
        'desc': 'Devout participation in the assigned Small Group (Mahderat).',
      },
      {
        'title': 'Respect',
        'desc':
            'Honor and submission to the hierarchy and spiritual leadership.',
      },
      {
        'title': 'Purity',
        'desc':
            'Maintaining spiritual and moral purity in personal and public life.',
      },
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: items.length,
      itemBuilder: (context, i) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.green.withOpacity(0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(items[i]['title']!,
                style: GoogleFonts.notoSansEthiopic(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  color: Colors.green.shade700,
                )),
            const SizedBox(height: 6),
            Text(items[i]['desc']!,
                style: GoogleFonts.notoSansEthiopic(
                  fontSize: 12.5,
                  height: 1.6,
                  fontStyle: FontStyle.italic,
                  color: isDark ? Colors.white60 : Colors.grey.shade700,
                )),
          ],
        ),
      ).animate().fadeIn(delay: (i * 100).ms).slideY(begin: 0.05),
    );
  }

  // ── Admin rules ─────────────────────────────────────────────────────────

  Widget _adminTab(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.06),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.amber.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: FaIcon(FontAwesomeIcons.gavel,
                        color: Colors.amber.shade700, size: 18),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text('Administrative Rules',
                        style: GoogleFonts.notoSansEthiopic(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: isDark ? Colors.white : AppColors.lightText,
                        )),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Rules regarding elections, appointments, and financial management follow the strict guidelines of the Central Council. Transparency and divine accountability are the pillars of our administration.',
                style: GoogleFonts.notoSansEthiopic(
                  fontSize: 13.5,
                  height: 1.8,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white70 : Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ).animate().fadeIn().slideY(begin: 0.05),
      ],
    );
  }
}
