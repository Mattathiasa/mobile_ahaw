import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../services/missionary_service.dart';
import '../../services/auth_service.dart';
import '../../services/permission_service.dart';
import '../../services/localization_service.dart';
import 'package:flutter_animate/flutter_animate.dart';

class MissionaryPage extends StatefulWidget {
  const MissionaryPage({super.key});

  @override
  State<MissionaryPage> createState() => _MissionaryPageState();
}

class _MissionaryPageState extends State<MissionaryPage>
    with SingleTickerProviderStateMixin {
  final MissionaryService _service = MissionaryService();
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = Provider.of<LocalizationService>(context);
    final perms = Provider.of<PermissionService>(context);
    final backgroundColor =
        isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final surfaceColor = isDark ? AppColors.darkSurface : Colors.white;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          loc.t('missionary'),
          style: GoogleFonts.notoSansEthiopic(
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : AppColors.lightText,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back,
              color: isDark ? Colors.white : AppColors.lightText),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppColors.primary,
          labelStyle: GoogleFonts.notoSansEthiopic(fontWeight: FontWeight.w900),
          tabs: const [
            Tab(text: 'Applications'),
            Tab(text: 'Reports'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _buildApplicationsTab(surfaceColor, isDark),
          _buildReportsTab(surfaceColor, isDark),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_tabs.index == 0) {
            if (!perms.can('canSubmitMissionaryApplication')) {
              _denied('submit a missionary application');
              return;
            }
            _openApplicationForm(context);
          } else {
            if (!perms.can('canSubmitMissionaryReport')) {
              _denied('submit a missionary report');
              return;
            }
            _openReportForm(context);
          }
        },
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(_tabs.index == 0 ? 'Apply' : 'Report',
            style: const TextStyle(color: Colors.white)),
      ),
    );
  }

  void _denied(String action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('You do not have permission to $action.')),
    );
  }

  // ── Applications ────────────────────────────────────────────────────────────

  Widget _buildApplicationsTab(Color surfaceColor, bool isDark) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _service.watchApplications(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _emptyState(FontAwesomeIcons.earthAfrica,
              'Unable to load applications.');
        }
        final docs = snapshot.data ?? [];
        if (docs.isEmpty) {
          return _emptyState(
              FontAwesomeIcons.earthAfrica, 'No missionary applications yet.');
        }
        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final d = docs[index];
            return _card(
              index: index,
              surfaceColor: surfaceColor,
              isDark: isDark,
              icon: FontAwesomeIcons.globe,
              iconColor: Colors.orange,
              title: d['desiredLocation'] ?? 'Unknown Location',
              subtitle: d['missionaryType'] ?? '',
              body: d['description'] ?? '',
              footerLeft: 'Status: ${d['status'] ?? 'Pending'}',
              footerRight: d['fullName'] ?? '',
            );
          },
        );
      },
    );
  }

  // ── Reports ─────────────────────────────────────────────────────────────────

  Widget _buildReportsTab(Color surfaceColor, bool isDark) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _service.watchReports(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _emptyState(
              FontAwesomeIcons.fileLines, 'Unable to load reports.');
        }
        final docs = snapshot.data ?? [];
        if (docs.isEmpty) {
          return _emptyState(
              FontAwesomeIcons.fileLines, 'No missionary reports yet.');
        }
        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final d = docs[index];
            final stats = (d['stats'] as Map<String, dynamic>?) ?? {};
            return _card(
              index: index,
              surfaceColor: surfaceColor,
              isDark: isDark,
              icon: FontAwesomeIcons.handHoldingHeart,
              iconColor: AppColors.primary,
              title: d['title'] ?? 'Report',
              subtitle: d['location'] ?? '',
              body: d['content'] ?? '',
              footerLeft:
                  'Reached: ${stats['peopleReached'] ?? 0} · Baptized: ${stats['baptized'] ?? 0}',
              footerRight: d['date']?.toString() ?? '',
            );
          },
        );
      },
    );
  }

  // ── Shared card ─────────────────────────────────────────────────────────────

  Widget _card({
    required int index,
    required Color surfaceColor,
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String body,
    required String footerLeft,
    required String footerRight,
  }) {
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
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: FaIcon(icon, color: iconColor, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.notoSansEthiopic(
                          fontWeight: FontWeight.w900, fontSize: 18),
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        style: GoogleFonts.notoSansEthiopic(
                            fontSize: 11,
                            color: Colors.grey,
                            fontWeight: FontWeight.bold),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (body.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              body,
              style: GoogleFonts.notoSansEthiopic(
                  fontSize: 14,
                  color: isDark ? Colors.white70 : Colors.black87,
                  height: 1.5),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  footerLeft,
                  style: GoogleFonts.notoSansEthiopic(
                      fontSize: 10,
                      color: Colors.grey,
                      fontWeight: FontWeight.bold),
                ),
              ),
              if (footerRight.isNotEmpty)
                Text(
                  footerRight,
                  style: GoogleFonts.notoSansEthiopic(
                      fontSize: 10,
                      color: Colors.grey,
                      fontWeight: FontWeight.bold),
                ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: (index * 100).ms).slideY(begin: 0.1);
  }

  Widget _emptyState(IconData icon, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FaIcon(icon, size: 80, color: AppColors.primary.withOpacity(0.2)),
          const SizedBox(height: 20),
          Text(
            message,
            style: GoogleFonts.notoSansEthiopic(
                fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  // ── Forms ─────────────────────────────────────────────────────────────────

  void _openApplicationForm(BuildContext context) {
    final user = Provider.of<AuthService>(context, listen: false).userModel;
    if (user == null) return;
    final locationCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String type = 'FullTime';
    final formKey = GlobalKey<FormState>();

    _showSheet(context, 'Missionary Application', formKey, [
      _textField(locationCtrl, 'Desired Location', required: true),
      StatefulBuilder(
        builder: (ctx, setLocal) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: DropdownButtonFormField<String>(
            value: type,
            decoration: const InputDecoration(
                labelText: 'Type', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'FullTime', child: Text('Full Time')),
              DropdownMenuItem(value: 'PartTime', child: Text('Part Time')),
            ],
            onChanged: (v) => setLocal(() => type = v ?? 'FullTime'),
          ),
        ),
      ),
      _textField(descCtrl, 'Description', maxLines: 3, required: true),
    ], () async {
      await _service.createApplication(
        desiredLocation: locationCtrl.text.trim(),
        missionaryType: type,
        description: descCtrl.text.trim(),
        userId: user.id,
        fullName: user.fullNameEnglish ?? user.fullName ?? user.username,
        phoneNumber: user.phone,
      );
    });
  }

  void _openReportForm(BuildContext context) {
    final user = Provider.of<AuthService>(context, listen: false).userModel;
    if (user == null) return;
    final titleCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    final reachedCtrl = TextEditingController(text: '0');
    final baptizedCtrl = TextEditingController(text: '0');
    final formKey = GlobalKey<FormState>();

    _showSheet(context, 'Missionary Report', formKey, [
      _textField(titleCtrl, 'Title', required: true),
      _textField(locationCtrl, 'Location', required: true),
      _textField(contentCtrl, 'Content', maxLines: 4, required: true),
      Row(children: [
        Expanded(
            child: _textField(reachedCtrl, 'People Reached',
                keyboardType: TextInputType.number)),
        const SizedBox(width: 12),
        Expanded(
            child: _textField(baptizedCtrl, 'Baptized',
                keyboardType: TextInputType.number)),
      ]),
    ], () async {
      await _service.createReport(
        title: titleCtrl.text.trim(),
        location: locationCtrl.text.trim(),
        content: contentCtrl.text.trim(),
        peopleReached: int.tryParse(reachedCtrl.text.trim()) ?? 0,
        baptized: int.tryParse(baptizedCtrl.text.trim()) ?? 0,
        missionaryId: user.id,
        date: DateTime.now().toIso8601String().split('T').first,
      );
    });
  }

  void _showSheet(BuildContext context, String title,
      GlobalKey<FormState> formKey, List<Widget> fields, Future<void> Function() onSubmit) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.all(20),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: GoogleFonts.notoSansEthiopic(
                            fontSize: 18, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 16),
                    ...fields,
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding:
                                const EdgeInsets.symmetric(vertical: 14)),
                        onPressed: () async {
                          if (!formKey.currentState!.validate()) return;
                          await onSubmit();
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        child: const Text('Submit',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _textField(TextEditingController ctrl, String label,
      {bool required = false,
      int maxLines = 1,
      TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
            : null,
      ),
    );
  }
}
