import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';


class DashboardStats {
  final int totalMembers;
  final int activeAnnouncements;
  final int pendingReports;
  final int upcomingMeetings;

  DashboardStats({
    required this.totalMembers,
    required this.activeAnnouncements,
    required this.pendingReports,
    required this.upcomingMeetings,
  });
}

class DashboardData {
  final DashboardStats stats;
  final List<Map<String, dynamic>> recentAnnouncements;
  final List<Map<String, dynamic>> recentReports;
  final List<Map<String, dynamic>> upcomingMeetings;

  DashboardData({
    required this.stats,
    required this.recentAnnouncements,
    required this.recentReports,
    required this.upcomingMeetings,
  });
}

class DashboardService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Counts members within the caller's directory scope. Returns 0 on a
  /// permission-denied (parish caller without a resolvable parish) rather than
  /// throwing, so the rest of the dashboard still loads.
  Future<int> _scopedMemberCount({
    required bool wholeDirectory,
    String? atbiyaId,
  }) async {
    try {
      if (wholeDirectory) {
        final snap = await _db.collection('users').count().get();
        return snap.count ?? 0;
      }
      if (atbiyaId == null || atbiyaId.isEmpty) return 0;
      final snap = await _db
          .collection('users')
          .where('atbiyaId', isEqualTo: atbiyaId)
          .count()
          .get();
      return snap.count ?? 0;
    } catch (e) {
      debugPrint('[Dashboard] scoped member count failed: $e');
      return 0;
    }
  }

  Future<DashboardData> getDashboardData({
    bool wholeDirectory = true,
    String? atbiyaId,
  }) async {
    // Match React's new Date().toISOString()
    final now = DateTime.now().toUtc().toIso8601String();

    try {
      // 1. Get total counts (Aggregate queries are efficient).
      //    The members count is scoped to what firestore.rules allows for this
      //    caller, and guarded on its own so a permission-denied count for a
      //    parish user doesn't zero out the rest of the dashboard.
      final totalMembersTask = _scopedMemberCount(
          wholeDirectory: wholeDirectory, atbiyaId: atbiyaId);
      final totalAnnouncementsTask = _db.collection('announcements').count().get();
      final totalReportsTask = _db.collection('reports').count().get();
      final upcomingMeetingsCountTask = _db.collection('meetings')
          .where('scheduledDate', isGreaterThanOrEqualTo: now)
          .count().get();

      // 2. Get recent items for lists
      final recentAnnouncementsTask = _db.collection('announcements').orderBy('createdAt', descending: true).limit(5).get();
      final recentReportsTask = _db.collection('reports').orderBy('createdAt', descending: true).limit(5).get();
      final recentMeetingsTask = _db.collection('meetings')
          .where('scheduledDate', isGreaterThanOrEqualTo: now)
          .orderBy('scheduledDate', descending: false)
          .limit(5)
          .get();

      final results = await Future.wait([
        totalMembersTask,
        totalAnnouncementsTask,
        totalReportsTask,
        upcomingMeetingsCountTask,
        recentAnnouncementsTask,
        recentReportsTask,
        recentMeetingsTask,
      ]);

      return DashboardData(
        stats: DashboardStats(
          totalMembers: results[0] as int,
          activeAnnouncements: (results[1] as AggregateQuerySnapshot).count ?? 0,
          pendingReports: (results[2] as AggregateQuerySnapshot).count ?? 0,
          upcomingMeetings: (results[3] as AggregateQuerySnapshot).count ?? 0,
        ),
        recentAnnouncements: (results[4] as QuerySnapshot).docs.map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>}).toList(),
        recentReports: (results[5] as QuerySnapshot).docs.map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>}).toList(),
        upcomingMeetings: (results[6] as QuerySnapshot).docs.map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>}).toList(),
      );
    } catch (e) {
      debugPrint("Error fetching dashboard data: $e");
      // Return empty data on error to avoid crashes
      return DashboardData(
        stats: DashboardStats(totalMembers: 0, activeAnnouncements: 0, pendingReports: 0, upcomingMeetings: 0),
        recentAnnouncements: [],
        recentReports: [],
        upcomingMeetings: [],
      );
    }
  }
}
