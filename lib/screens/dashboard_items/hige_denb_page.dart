import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../services/localization_service.dart';
import '../../widgets/dashboard/dashboard_scaffold.dart';
import '../../theme/app_colors.dart';

/// Mirrors the web HigeDenb page: the four governance rule cards plus the
/// important-notice banner.
class HigeDenbPage extends StatelessWidget {
  const HigeDenbPage({super.key});

  /// The four articles, as catalog keys rather than English text. The web
  /// renders the same articles from i18n so an admin can reword them from
  /// Settings; these used to be hardcoded here, so an edit made on the web
  /// never reached the app.
  static const _rules = [
    {
      'titleKey': 'pages.higeDenbGovernanceTitle',
      'icon': FontAwesomeIcons.shieldHalved,
      'color': Colors.indigo,
      'bodyKey': 'pages.higeDenbGovernanceBody',
    },
    {
      'titleKey': 'pages.higeDenbReportingTitle',
      'icon': FontAwesomeIcons.fileLines,
      'color': Colors.amber,
      'bodyKey': 'pages.higeDenbReportingBody',
    },
    {
      'titleKey': 'pages.higeDenbConductTitle',
      'icon': FontAwesomeIcons.bookOpen,
      'color': Colors.green,
      'bodyKey': 'pages.higeDenbConductBody',
    },
    {
      'titleKey': 'pages.higeDenbCommunicationTitle',
      'icon': FontAwesomeIcons.scaleBalanced,
      'color': AppColors.primary,
      'bodyKey': 'pages.higeDenbCommunicationBody',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final loc = Provider.of<LocalizationService>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DashboardScaffold(
      titleKey: 'nav.higeDenb',
      moduleKey: 'higeDenb',
      constrainWidth: false,
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          for (var i = 0; i < _rules.length; i++)
            _buildRuleCard(loc, _rules[i], isDark, i),
          _buildNoticeCard(loc),
        ],
      ),
    );
  }

  Widget _buildRuleCard(
      LocalizationService loc, Map<String, dynamic> rule, bool isDark, int index) {
    final color = rule['color'] as Color;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: FaIcon(rule['icon'] as FaIconData, color: color, size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(loc.t(rule['titleKey'] as String),
                    style: GoogleFonts.notoSansEthiopic(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      color: isDark ? Colors.white : AppColors.lightText,
                    )),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(loc.t(rule['bodyKey'] as String),
              style: GoogleFonts.notoSansEthiopic(
                fontSize: 12.5,
                height: 1.7,
                fontStyle: FontStyle.italic,
                color: isDark ? Colors.white60 : Colors.grey.shade700,
              )),
        ],
      ),
    ).animate().fadeIn(delay: (index * 100).ms).slideY(begin: 0.05);
  }

  Widget _buildNoticeCard(LocalizationService loc) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF204A7C), AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const FaIcon(FontAwesomeIcons.bookOpen,
                  color: Colors.white, size: 18),
              const SizedBox(width: 12),
              Text(loc.t('pages.importantNotice'),
                  style: GoogleFonts.notoSansEthiopic(
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                    color: Colors.white,
                  )),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            loc.t('pages.higeDenbNotice'),
            style: GoogleFonts.notoSansEthiopic(
              fontSize: 13,
              height: 1.8,
              fontStyle: FontStyle.italic,
              color: Colors.white.withValues(alpha: 0.92),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.05);
  }
}
