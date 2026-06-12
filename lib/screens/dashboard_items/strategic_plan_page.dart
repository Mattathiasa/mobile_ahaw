import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_colors.dart';
import 'package:flutter_animate/flutter_animate.dart';

class StrategicPlanPage extends StatefulWidget {
  const StrategicPlanPage({super.key});

  @override
  State<StrategicPlanPage> createState() => _StrategicPlanPageState();
}

class _StrategicPlanPageState extends State<StrategicPlanPage> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final List<Map<String, dynamic>> _mockGoals = [
    {
      'id': '1',
      'title': '50 Million Members in 50 Years',
      'description': 'Our long term vision for church growth and evangelism.',
      'targetYear': 2075,
      'currentValue': 1200000,
      'targetValue': 50000000,
      'unit': 'Members',
    },
    {
      'id': '2',
      'title': 'Plant 10,000 New Churches',
      'description': 'Establishing new places of worship across the region.',
      'targetYear': 2030,
      'currentValue': 2450,
      'targetValue': 10000,
      'unit': 'Churches',
    }
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final surfaceColor = isDark ? AppColors.darkSurface : Colors.white;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Strategic Plan',
          style: GoogleFonts.notoSansEthiopic(
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : AppColors.lightText,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : AppColors.lightText),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _db.collection('strategic-goals').snapshots(),
        builder: (context, snapshot) {
          final docs = snapshot.data?.docs ?? [];
          final goals = docs.isNotEmpty 
              ? docs.map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>}).toList()
              : _mockGoals;

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: goals.length,
            itemBuilder: (context, index) {
              return _buildGoalCard(context, goals[index], index, surfaceColor, isDark);
            },
          );
        },
      ),
    );
  }

  Widget _buildGoalCard(BuildContext context, Map<String, dynamic> goal, int index, Color surfaceColor, bool isDark) {
    final current = double.tryParse(goal['currentValue'].toString()) ?? 0;
    final target = double.tryParse(goal['targetValue'].toString()) ?? 1;
    final percentage = (current / target * 100).clamp(0, 100).toInt();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primary.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const FaIcon(FontAwesomeIcons.flag, color: AppColors.primary, size: 14),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goal['title'] ?? 'Untitled Goal',
                        style: GoogleFonts.notoSansEthiopic(fontWeight: FontWeight.w900, fontSize: 14, color: isDark ? Colors.white : AppColors.lightText),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        goal['description'] ?? '',
                        style: GoogleFonts.notoSansEthiopic(fontSize: 10, color: Colors.grey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    Text('TARGET', style: GoogleFonts.notoSansEthiopic(fontSize: 7, fontWeight: FontWeight.w900, color: Colors.grey)),
                    Text(
                      '${goal['targetYear']}',
                      style: GoogleFonts.notoSansEthiopic(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.primary),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.03),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$percentage%',
                      style: GoogleFonts.notoSansEthiopic(fontSize: 24, fontWeight: FontWeight.w900, color: isDark ? Colors.white : AppColors.lightText),
                    ),
                    const Icon(Icons.trending_up, color: Colors.green, size: 16),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: current / target,
                    minHeight: 8,
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildValueBox('Current ${goal['unit']}', current, isDark, false),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildValueBox('Target ${goal['unit']}', target, isDark, true),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: (index * 100).ms).slideY(begin: 0.05);
  }

  Widget _buildValueBox(String label, double value, bool isDark, bool isPrimary) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isPrimary ? AppColors.primary : (isDark ? Colors.black26 : Colors.white),
        borderRadius: BorderRadius.circular(20),
        border: isPrimary ? null : Border.all(color: AppColors.primary.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.notoSansEthiopic(fontSize: 8, fontWeight: FontWeight.bold, color: isPrimary ? Colors.white70 : Colors.grey),
          ),
          const SizedBox(height: 4),
          Text(
            value.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},'),
            style: GoogleFonts.notoSansEthiopic(fontSize: 14, fontWeight: FontWeight.w900, color: isPrimary ? Colors.white : null),
          ),
        ],
      ),
    );
  }

}
