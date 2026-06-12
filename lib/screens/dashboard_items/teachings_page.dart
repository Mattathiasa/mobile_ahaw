import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_colors.dart';

/// Mirrors the web Teaching page: lists the `teachings` collection
/// (title, speaker, serviceType, shortDescription, dateDelivered) with a
/// full-content detail sheet.
class TeachingsPage extends StatelessWidget {
  const TeachingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Teachings',
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
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('teachings')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.primary));
          }
          if (snapshot.hasError) {
            return _emptyState(
                isDark, Icons.error_outline, 'Could not load teachings');
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return _emptyState(isDark, FontAwesomeIcons.bookOpenReader,
                'No teachings published yet');
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data();
              return _TeachingCard(data: data, isDark: isDark, index: index);
            },
          );
        },
      ),
    );
  }

  Widget _emptyState(bool isDark, IconData icon, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 56, color: AppColors.primary.withOpacity(0.4)),
          const SizedBox(height: 16),
          Text(message,
              style: GoogleFonts.notoSansEthiopic(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              )),
        ],
      ),
    );
  }
}

class _TeachingCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isDark;
  final int index;

  const _TeachingCard(
      {required this.data, required this.isDark, required this.index});

  @override
  Widget build(BuildContext context) {
    final title = (data['title'] as String?) ?? 'Untitled';
    final speaker = (data['speaker'] as String?) ?? '';
    final serviceType = (data['serviceType'] as String?) ?? '';
    final shortDescription = (data['shortDescription'] as String?) ?? '';
    final dateDelivered = (data['dateDelivered'] as String?) ?? '';

    return GestureDetector(
      onTap: () => _showDetail(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.primary.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const FaIcon(FontAwesomeIcons.bookOpenReader,
                      color: AppColors.primary, size: 16),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: GoogleFonts.notoSansEthiopic(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            color: isDark ? Colors.white : AppColors.lightText,
                          )),
                      if (speaker.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(speaker,
                            style: GoogleFonts.notoSansEthiopic(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            )),
                      ],
                    ],
                  ),
                ),
                if (serviceType.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(serviceType.toUpperCase(),
                        style: GoogleFonts.notoSansEthiopic(
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                          letterSpacing: 0.4,
                        )),
                  ),
              ],
            ),
            if (shortDescription.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(shortDescription,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.notoSansEthiopic(
                    fontSize: 12,
                    height: 1.5,
                    color: isDark ? Colors.white60 : Colors.grey.shade600,
                  )),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                if (dateDelivered.isNotEmpty) ...[
                  const Icon(Icons.calendar_today_outlined,
                      size: 11, color: Colors.grey),
                  const SizedBox(width: 5),
                  Text(dateDelivered,
                      style: GoogleFonts.notoSansEthiopic(
                          fontSize: 10, color: Colors.grey)),
                ],
                const Spacer(),
                Text('READ MORE',
                    style: GoogleFonts.notoSansEthiopic(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                      letterSpacing: 0.6,
                    )),
              ],
            ),
          ],
        ),
      ).animate().fadeIn(delay: (index * 80).ms).slideY(begin: 0.05),
    );
  }

  void _showDetail(BuildContext context) {
    final title = (data['title'] as String?) ?? 'Untitled';
    final speaker = (data['speaker'] as String?) ?? '';
    final fullContent = (data['fullContent'] as String?) ??
        (data['shortDescription'] as String?) ??
        '';
    final dateDelivered = (data['dateDelivered'] as String?) ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor:
          isDark ? AppColors.darkSurface : AppColors.lightBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(title,
                  style: GoogleFonts.notoSansEthiopic(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : AppColors.lightText,
                  )),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (speaker.isNotEmpty) ...[
                    const Icon(Icons.person_outline,
                        size: 14, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(speaker,
                        style: GoogleFonts.notoSansEthiopic(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        )),
                    const SizedBox(width: 16),
                  ],
                  if (dateDelivered.isNotEmpty) ...[
                    const Icon(Icons.calendar_today_outlined,
                        size: 12, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(dateDelivered,
                        style: GoogleFonts.notoSansEthiopic(
                            fontSize: 11, color: Colors.grey)),
                  ],
                ],
              ),
              const SizedBox(height: 20),
              Text(fullContent,
                  style: GoogleFonts.notoSansEthiopic(
                    fontSize: 14,
                    height: 1.8,
                    color: isDark ? Colors.white70 : AppColors.lightText,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}
