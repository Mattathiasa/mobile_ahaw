import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';

/// Mirrors the web Notifications page: per-user notifications from the
/// `notifications` collection (title, message, type, senderName, status),
/// with mark-as-read, mark-all-read, and delete.
class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = context.watch<AuthService>().userModel;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Notifications',
            style: GoogleFonts.notoSansEthiopic(
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : AppColors.lightText,
            )),
        leading: IconButton(
          icon: Icon(Icons.arrow_back,
              color: isDark ? Colors.white : AppColors.lightText),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (user != null)
            IconButton(
              tooltip: 'Mark all as read',
              icon: const Icon(Icons.done_all, color: AppColors.primary),
              onPressed: () => _markAllRead(context, user.id),
            ),
        ],
      ),
      body: user == null
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('notifications')
                  .where('userId', isEqualTo: user.id)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child:
                          CircularProgressIndicator(color: AppColors.primary));
                }
                if (snapshot.hasError) {
                  return _empty(Icons.error_outline,
                      'Could not load notifications');
                }

                final docs = (snapshot.data?.docs ?? []).toList()
                  ..sort((a, b) {
                    final at = a.data()['createdAt'];
                    final bt = b.data()['createdAt'];
                    if (at is Timestamp && bt is Timestamp) {
                      return bt.compareTo(at);
                    }
                    return 0;
                  });

                if (docs.isEmpty) {
                  return _empty(
                      Icons.notifications_none, 'No notifications yet');
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: docs.length,
                  itemBuilder: (context, index) =>
                      _NotificationCard(doc: docs[index], isDark: isDark, index: index),
                );
              },
            ),
    );
  }

  Widget _empty(IconData icon, String message) {
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

  Future<void> _markAllRead(BuildContext context, String userId) async {
    final db = FirebaseFirestore.instance;
    final snap = await db
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'unread')
        .get();
    if (snap.docs.isEmpty) return;
    final batch = db.batch();
    for (final d in snap.docs) {
      batch.update(d.reference, {'status': 'read'});
    }
    await batch.commit();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('All notifications marked as read',
            style: GoogleFonts.notoSansEthiopic()),
      ));
    }
  }
}

class _NotificationCard extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final bool isDark;
  final int index;

  const _NotificationCard(
      {required this.doc, required this.isDark, required this.index});

  IconData _typeIcon(String? type) {
    switch (type) {
      case 'announcement':
        return Icons.campaign_outlined;
      case 'meeting':
        return Icons.event_outlined;
      case 'report_comment':
        return Icons.comment_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = doc.data();
    final title = (data['title'] as String?) ?? 'Notification';
    final message = (data['message'] as String?) ?? '';
    final senderName = (data['senderName'] as String?) ?? '';
    final unread = data['status'] == 'unread';
    final createdAt = data['createdAt'];
    String when = '';
    if (createdAt is Timestamp) {
      final d = createdAt.toDate();
      when =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: unread
            ? AppColors.primary.withOpacity(0.06)
            : (isDark ? Colors.white.withOpacity(0.03) : Colors.white),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: unread
              ? AppColors.primary.withOpacity(0.4)
              : AppColors.primary.withOpacity(0.1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_typeIcon(data['type'] as String?),
                color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(title,
                          style: GoogleFonts.notoSansEthiopic(
                            fontWeight: FontWeight.w900,
                            fontSize: 13.5,
                            color: isDark ? Colors.white : AppColors.lightText,
                          )),
                    ),
                    if (unread)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                if (message.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(message,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.notoSansEthiopic(
                        fontSize: 12,
                        height: 1.5,
                        color: isDark ? Colors.white60 : Colors.grey.shade600,
                      )),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (senderName.isNotEmpty)
                      Text('From: $senderName  ',
                          style: GoogleFonts.notoSansEthiopic(
                              fontSize: 10, color: Colors.grey)),
                    Text(when,
                        style: GoogleFonts.notoSansEthiopic(
                            fontSize: 10, color: Colors.grey)),
                    const Spacer(),
                    if (unread)
                      GestureDetector(
                        onTap: () => doc.reference.update({'status': 'read'}),
                        child: const Icon(Icons.check,
                            size: 16, color: AppColors.primary),
                      ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () => doc.reference.delete(),
                      child: Icon(Icons.delete_outline,
                          size: 16, color: Colors.red.shade400),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: (index * 60).ms);
  }
}
