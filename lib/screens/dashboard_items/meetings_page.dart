import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_colors.dart';
import '../../services/permission_service.dart';
import '../../services/meeting_service.dart';
import '../../models/meeting_model.dart';
import 'package:intl/intl.dart';

class MeetingsPage extends StatefulWidget {
  const MeetingsPage({super.key});

  @override
  State<MeetingsPage> createState() => _MeetingsPageState();
}

class _MeetingsPageState extends State<MeetingsPage> {
  final MeetingService _meetingService = MeetingService();

  void _showCreateSheet(BuildContext context) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    DateTime? selectedDate;
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0D2440) : const Color(0xFFF8FAFF),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Schedule Meeting', style: GoogleFonts.notoSansEthiopic(fontSize: 22, fontWeight: FontWeight.w900, color: isDark ? Colors.white : AppColors.lightText)),
                      const SizedBox(height: 4),
                      Text('Create a new leadership meeting and notify members', style: GoogleFonts.notoSansEthiopic(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey)),
                    ],
                  ),
                ),
                const Divider(height: 32),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Meeting Title *', isDark),
                        _buildTextField(titleCtrl, 'Enter meeting title', isDark),
                        const SizedBox(height: 20),
                        _buildLabel('Date & Time *', isDark),
                        _buildDatePicker(context, selectedDate, (d) => setSheet(() => selectedDate = d), isDark),
                        const SizedBox(height: 20),
                        _buildLabel('Description *', isDark),
                        _buildTextField(descCtrl, 'Enter meeting description and agenda', isDark, maxLines: 4),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), padding: const EdgeInsets.symmetric(vertical: 14)),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: saving ? null : () async {
                            if (titleCtrl.text.isEmpty || descCtrl.text.isEmpty || selectedDate == null) return;
                            setSheet(() => saving = true);
                            try {
                              await _meetingService.createMeeting(MeetingModel(
                                id: '',
                                title: titleCtrl.text,
                                description: descCtrl.text,
                                scheduledDate: selectedDate!.toIso8601String(),
                              ));
                              if (ctx.mounted) Navigator.pop(ctx);
                              _showSnack('Meeting scheduled!', success: true);
                            } catch (e) {
                              _showSnack('Failed: $e');
                            } finally {
                              if (ctx.mounted) setSheet(() => saving = false);
                            }
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), padding: const EdgeInsets.symmetric(vertical: 14)),
                          child: saving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Schedule Meeting'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showSnack(String msg, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? AppColors.success : AppColors.sacredRed,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final perms = Provider.of<PermissionService>(context);
    final canSchedule = perms.isSuperAdmin || perms.can('canScheduleMeeting');

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Meetings', style: GoogleFonts.notoSansEthiopic(fontWeight: FontWeight.w900, color: isDark ? Colors.white : AppColors.lightText)),
        leading: IconButton(icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : AppColors.lightText), onPressed: () => Navigator.pop(context)),
        actions: [
          if (canSchedule)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ElevatedButton.icon(
                onPressed: () => _showCreateSheet(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Schedule', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
            ),
        ],
      ),
      body: StreamBuilder<List<MeetingModel>>(
        stream: _meetingService.getMeetingsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          
          final meetings = snapshot.data ?? [];
          final now = DateTime.now();
          final upcoming = meetings.where((m) {
            final d = DateTime.tryParse(m.scheduledDate);
            return d != null && (d.isAfter(now) || d.day == now.day && d.month == now.month && d.year == now.year);
          }).toList();
          final past = meetings.where((m) {
            final d = DateTime.tryParse(m.scheduledDate);
            return d != null && d.isBefore(now) && !(d.day == now.day && d.month == now.month && d.year == now.year);
          }).toList();

          if (meetings.isEmpty) return _buildEmptyState(isDark);

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (upcoming.isNotEmpty) ...[
                _buildSectionHeader('Upcoming Meetings', isDark),
                const SizedBox(height: 16),
                ...upcoming.map((m) => _buildMeetingCard(m, isDark, true)),
                const SizedBox(height: 32),
              ],
              if (past.isNotEmpty) ...[
                _buildSectionHeader('Past Meetings', isDark),
                const SizedBox(height: 16),
                ...past.map((m) => _buildMeetingCard(m, isDark, false)),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Row(
      children: [
        Container(width: 4, height: 20, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 12),
        Text(title, style: GoogleFonts.notoSansEthiopic(fontSize: 18, fontWeight: FontWeight.w900, color: isDark ? Colors.white70 : AppColors.lightText.withOpacity(0.7))),
      ],
    );
  }

  Widget _buildMeetingCard(MeetingModel meeting, bool isDark, bool isUpcoming) {
    final date = DateTime.tryParse(meeting.scheduledDate) ?? DateTime.now();
    final timeStr = DateFormat('jm').format(date);
    final dateStr = DateFormat('MMM d, yyyy').format(date);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primary.withOpacity(0.1)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(meeting.title, style: GoogleFonts.notoSansEthiopic(fontSize: 18, fontWeight: FontWeight.w900, color: isDark ? Colors.white : AppColors.lightText))),
              if (isUpcoming)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                  child: const Text('UPCOMING', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: AppColors.success, letterSpacing: 1)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildIconInfo(Icons.calendar_today, dateStr, isDark),
              const SizedBox(width: 16),
              _buildIconInfo(Icons.access_time, timeStr, isDark),
            ],
          ),
          const SizedBox(height: 12),
          Text(meeting.description, style: GoogleFonts.notoSansEthiopic(fontSize: 13, color: isDark ? Colors.white60 : Colors.black54, height: 1.5)),
          if (isUpcoming) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _showSnack('Added to calendar! (Simulation)');
                    },
                    icon: const Icon(Icons.calendar_month, size: 16),
                    label: const Text('Add to Calendar'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary.withOpacity(0.1), foregroundColor: AppColors.primary, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                ),
                const SizedBox(width: 12),
                if (Provider.of<PermissionService>(context, listen: false).can('canDeleteMeeting'))
                  IconButton(
                    onPressed: () => _confirmDelete(meeting),
                    icon: const Icon(Icons.delete_outline, color: AppColors.sacredRed, size: 20),
                    style: IconButton.styleFrom(backgroundColor: AppColors.sacredRed.withOpacity(0.1), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  ),
              ],
            ),
          ],
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1);
  }

  void _confirmDelete(MeetingModel meeting) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Meeting'),
        content: Text('Are you sure you want to delete "${meeting.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () async {
            await _meetingService.deleteMeeting(meeting.id);
            if (ctx.mounted) Navigator.pop(ctx);
            _showSnack('Meeting deleted');
          }, child: const Text('Delete', style: TextStyle(color: AppColors.sacredRed))),
        ],
      ),
    );
  }

  Widget _buildIconInfo(IconData icon, String text, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.primary),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.grey[700])),
      ],
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_month_outlined, size: 64, color: AppColors.primary.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text('NO MEETINGS SCHEDULED', style: GoogleFonts.notoSansEthiopic(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 2, color: Colors.grey.withOpacity(0.5))),
        ],
      ),
    );
  }

  Widget _buildLabel(String text, bool isDark) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(text.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.primary, letterSpacing: 1.2)));

  Widget _buildTextField(TextEditingController ctrl, String hint, bool isDark, {int maxLines = 1}) => Container(
    decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.05), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.primary.withOpacity(0.1))),
    child: TextField(controller: ctrl, maxLines: maxLines, decoration: InputDecoration(hintText: hint, border: InputBorder.none, contentPadding: const EdgeInsets.all(16))),
  );

  Widget _buildDatePicker(BuildContext context, DateTime? value, ValueChanged<DateTime> onChanged, bool isDark) => GestureDetector(
    onTap: () async {
      final d = await showDatePicker(context: context, initialDate: value ?? DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
      if (d != null && context.mounted) {
        final t = await showTimePicker(context: context, initialTime: TimeOfDay.now());
        if (t != null) onChanged(DateTime(d.year, d.month, d.day, t.hour, t.minute));
      }
    },
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.05), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.primary.withOpacity(0.1))),
      child: Row(
        children: [
          const Icon(Icons.calendar_today, size: 18, color: AppColors.primary),
          const SizedBox(width: 12),
          Text(value == null ? 'Select Date & Time' : DateFormat('MMM d, yyyy - jm').format(value), style: TextStyle(color: value == null ? Colors.grey : (isDark ? Colors.white : Colors.black))),
          const Spacer(),
          const Icon(Icons.arrow_drop_down),
        ],
      ),
    ),
  );
}
