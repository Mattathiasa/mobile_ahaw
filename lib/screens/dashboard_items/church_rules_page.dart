import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../services/church_rules_service.dart';
import '../../services/localization_service.dart';
import '../../theme/app_colors.dart';

/// Church Rules (Hige Denb) — three categories synced from the web admin
/// (siteConfig/churchRules): Regulations (ደንብ), Directives (መመሪያ), Policies.
class ChurchRulesPage extends StatelessWidget {
  const ChurchRulesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = Provider.of<LocalizationService>(context);
    final rules = Provider.of<ChurchRulesService>(context);

    final categories = [
      _Category('Regulations', 'ደንብ', FontAwesomeIcons.scaleBalanced, Colors.indigo, rules.denb),
      _Category('Directives', 'መመሪያ', FontAwesomeIcons.bookOpen, Colors.green, rules.memerya),
      _Category('Policies', 'ፖሊሲ', FontAwesomeIcons.clipboardList, Colors.amber, rules.policies),
    ];

    return DefaultTabController(
      length: categories.length,
      child: Scaffold(
        backgroundColor:
            isDark ? AppColors.darkBackground : AppColors.lightBackground,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(loc.t('churchRules'),
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
            tabs: categories
                .map((c) => Tab(text: '${c.label} (${c.amharic})'))
                .toList(),
          ),
        ),
        body: !rules.loaded
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary))
            : TabBarView(
                children: categories
                    .map((cat) => _buildList(cat, isDark))
                    .toList(),
              ),
      ),
    );
  }

  Widget _buildList(_Category cat, bool isDark) {
    if (cat.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FaIcon(cat.icon, size: 48, color: cat.color.withOpacity(0.4)),
            const SizedBox(height: 14),
            Text('No ${cat.label.toLowerCase()} yet',
                style: GoogleFonts.notoSansEthiopic(
                    fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: cat.items.length,
      itemBuilder: (context, i) {
        final item = cat.items[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cat.color.withOpacity(0.15)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: cat.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: FaIcon(cat.icon, size: 13, color: cat.color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(item.title,
                        style: GoogleFonts.notoSansEthiopic(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          color: isDark ? Colors.white : AppColors.lightText,
                        )),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(item.content,
                  style: GoogleFonts.notoSansEthiopic(
                    fontSize: 13,
                    height: 1.7,
                    fontStyle: FontStyle.italic,
                    color: isDark ? Colors.white60 : Colors.grey.shade700,
                  )),
            ],
          ),
        ).animate().fadeIn(delay: (i * 80).ms).slideY(begin: 0.05);
      },
    );
  }
}

class _Category {
  final String label;
  final String amharic;
  final IconData icon;
  final Color color;
  final List<RuleItem> items;
  const _Category(this.label, this.amharic, this.icon, this.color, this.items);
}
