import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_colors.dart';
import 'package:flutter_animate/flutter_animate.dart';

class MissionaryPage extends StatefulWidget {
  const MissionaryPage({super.key});

  @override
  State<MissionaryPage> createState() => _MissionaryPageState();
}

class _MissionaryPageState extends State<MissionaryPage> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

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
          'Missionary Work',
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
        stream: _db.collection('missionary-work').orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              return _buildMissionaryCard(context, data, index, surfaceColor, isDark);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildMissionaryCard(BuildContext context, Map<String, dynamic> data, int index, Color surfaceColor, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primary.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const FaIcon(FontAwesomeIcons.globe, color: Colors.orange, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  data['location'] ?? 'Unknown Location',
                  style: GoogleFonts.notoSansEthiopic(fontWeight: FontWeight.w900, fontSize: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            data['description'] ?? '',
            style: GoogleFonts.notoSansEthiopic(fontSize: 14, color: isDark ? Colors.white70 : Colors.black87, height: 1.5),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Status: ${data['status'] ?? 'Active'}',
                style: GoogleFonts.notoSansEthiopic(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
              ),
              if (data['date'] != null)
                Text(
                  'Date: ${data['date']}',
                  style: GoogleFonts.notoSansEthiopic(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
                ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: (index * 100).ms).slideY(begin: 0.1);
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FaIcon(FontAwesomeIcons.earthAfrica, size: 80, color: AppColors.primary.withOpacity(0.2)),
          const SizedBox(height: 20),
          Text(
            'No missionary work records',
            style: GoogleFonts.notoSansEthiopic(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
