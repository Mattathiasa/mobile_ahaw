import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_colors.dart';

/// Mirrors the web HigeDenb page: the four governance rule cards plus the
/// important-notice banner.
class HigeDenbPage extends StatelessWidget {
  const HigeDenbPage({super.key});

  static const _rules = [
    {
      'title': 'Church Governance Structure',
      'icon': FontAwesomeIcons.shieldHalved,
      'color': Colors.indigo,
      'content':
          'The Ethiopian Orthodox Tewahedo Church follows a hierarchical structure starting from Sinodos at the highest level, followed by KuamiSinodos (9 units), Memriya (7 members), Zone, Atbiya (individual churches), EnkesekaseMaikel, and HiyawanMahderat at the base level.',
    },
    {
      'title': 'Reporting Requirements',
      'icon': FontAwesomeIcons.fileLines,
      'color': Colors.amber,
      'content':
          'All Memriya members and higher levels must submit regular reports on church activities, including attendance, financial matters, and ministry progress. Reports should be submitted according to the designated frequency: weekly, monthly, or yearly.',
    },
    {
      'title': 'Ministry Conduct',
      'icon': FontAwesomeIcons.bookOpen,
      'color': Colors.green,
      'content':
          'All church members serving in ministry roles must uphold the highest standards of spiritual conduct, maintain regular attendance at services, and actively participate in their assigned ministry areas. Sunday School teachers, youth leaders, and other ministry workers must complete appropriate training.',
    },
    {
      'title': 'Communication Protocol',
      'icon': FontAwesomeIcons.scaleBalanced,
      'color': AppColors.primary,
      'content':
          'Official announcements can only be made by Memriya level and above. All communications must follow the established chain of command. Urgent matters should be escalated through proper channels to ensure timely response and appropriate action.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Hige Denb',
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
          for (var i = 0; i < _rules.length; i++)
            _buildRuleCard(_rules[i], isDark, i),
          _buildNoticeCard(),
        ],
      ),
    );
  }

  Widget _buildRuleCard(Map<String, dynamic> rule, bool isDark, int index) {
    final color = rule['color'] as Color;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: FaIcon(rule['icon'] as IconData, color: color, size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(rule['title'] as String,
                    style: GoogleFonts.notoSansEthiopic(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      color: isDark ? Colors.white : AppColors.lightText,
                    )),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(rule['content'] as String,
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

  Widget _buildNoticeCard() {
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
              Text('Important Notice',
                  style: GoogleFonts.notoSansEthiopic(
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                    color: Colors.white,
                  )),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'These regulations are based on the canonical laws of the Ethiopian Orthodox Tewahedo Church and should be followed by all members. For detailed information about specific rules or to request clarification, please contact your local Memriya representative or higher church authority.',
            style: GoogleFonts.notoSansEthiopic(
              fontSize: 13,
              height: 1.8,
              fontStyle: FontStyle.italic,
              color: Colors.white.withOpacity(0.92),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.05);
  }
}
