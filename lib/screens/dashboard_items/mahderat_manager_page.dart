import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../services/mahderat_service.dart';
import '../../services/phone_utils.dart';
import '../../theme/app_colors.dart';
import 'announcements_page.dart' show buildLabel, buildTextField, FormSheet;

/// Manage the Mahedherat (fellowship groups) of one congregation — the mobile
/// port of the web's MahderatManager component.
///
/// Groups live in the `hierarchy` collection at level Mahderat with the
/// congregation as `parentId`; the form mirrors the web's fields (names,
/// meeting day/time, landmark, leader, phone) and the phone is normalized the
/// same way. Deactivating hides the group from members without orphaning
/// anyone already in it.
class MahderatManagerScreen extends StatefulWidget {
  final String atbiyaId;
  final String atbiyaName;
  /// False renders the list read-only.
  final bool canEdit;

  const MahderatManagerScreen({
    super.key,
    required this.atbiyaId,
    required this.atbiyaName,
    required this.canEdit,
  });

  @override
  State<MahderatManagerScreen> createState() => _MahderatManagerScreenState();
}

class _MahderatManagerScreenState extends State<MahderatManagerScreen> {
  final MahderatService _service = MahderatService();
  List<Mahder>? _groups;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.atbiyaId.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    try {
      final groups =
          await _service.listByCongregation(widget.atbiyaId, includeInactive: true);
      if (mounted) {
        setState(() {
          _groups = groups;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not load the groups.';
        });
      }
    }
  }

  void _openEditor({Mahder? existing}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MahderFormSheet(
        service: _service,
        atbiyaId: widget.atbiyaId,
        atbiyaName: widget.atbiyaName,
        existing: existing,
        isDark: isDark,
        onSaved: _load,
      ),
    );
  }

  Future<void> _toggleActive(Mahder m) async {
    try {
      await _service.setActive(m.id, !m.active);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not update that group.'),
          backgroundColor: AppColors.sacredRed,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final groups = _groups ?? const [];

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Mahedherat',
            style: GoogleFonts.notoSansEthiopic(
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : AppColors.lightText)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back,
              color: isDark ? Colors.white : AppColors.lightText),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
              onPressed: _load,
              icon: const Icon(Icons.refresh, color: AppColors.primary)),
        ],
      ),
      floatingActionButton: widget.canEdit
          ? FloatingActionButton(
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add, color: Colors.white),
              onPressed: () => _openEditor(),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_error != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppColors.sacredRed.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(_error!,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.sacredRed)),
                  ),
                if (groups.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 60),
                    child: Column(children: [
                      Icon(Icons.groups_outlined,
                          size: 64,
                          color: AppColors.primary.withValues(alpha: 0.2)),
                      const SizedBox(height: 16),
                      Text('NO MAHEDHERAT YET',
                          style: GoogleFonts.notoSansEthiopic(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                              color: Colors.grey.withValues(alpha: 0.5))),
                      const SizedBox(height: 8),
                      Text(
                        'Small Bible-study groups within ${widget.atbiyaName}, for people living close to each other.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.notoSansEthiopic(
                            fontSize: 12, color: Colors.grey),
                      ),
                    ]),
                  )
                else
                  for (var i = 0; i < groups.length; i++) ...[
                    _MahderCard(
                      group: groups[i],
                      canEdit: widget.canEdit,
                      onEdit: () => _openEditor(existing: groups[i]),
                      onToggle: () => _toggleActive(groups[i]),
                    ).animate().fadeIn(delay: (i * 40).ms).slideY(begin: 0.08),
                    if (i < groups.length - 1) const SizedBox(height: 10),
                  ],
              ],
            ),
    );
  }
}

class _MahderCard extends StatelessWidget {
  final Mahder group;
  final bool canEdit;
  final VoidCallback onEdit;
  final VoidCallback onToggle;

  const _MahderCard({
    required this.group,
    required this.canEdit,
    required this.onEdit,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(group.name,
                      style: GoogleFonts.notoSansEthiopic(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color:
                              isDark ? Colors.white : AppColors.lightText)),
                  if (group.nameAmharic?.isNotEmpty ?? false)
                    Text(group.nameAmharic!,
                        style: GoogleFonts.notoSansEthiopic(
                            fontSize: 12, color: Colors.grey[500])),
                  if (!group.active)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('HIDDEN',
                          style: GoogleFonts.notoSansEthiopic(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: Colors.grey)),
                    ),
                  if (!group.hasCoords)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('NO PIN',
                          style: GoogleFonts.notoSansEthiopic(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: Colors.amber[800])),
                    ),
                ],
              ),
            ),
            if (canEdit)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert,
                    color: AppColors.primary, size: 20),
                onSelected: (v) {
                  if (v == 'edit') onEdit();
                  if (v == 'toggle') onToggle();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                      value: 'edit',
                      child: Row(children: [
                        Icon(Icons.edit_outlined,
                            size: 16, color: AppColors.primary),
                        SizedBox(width: 8),
                        Text('Edit'),
                      ])),
                  PopupMenuItem(
                      value: 'toggle',
                      child: Row(children: [
                        Icon(
                            group.active
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 16,
                            color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(group.active ? 'Hide' : 'Show'),
                      ])),
                ],
              ),
          ]),
          if (group.locationDisplay?.isNotEmpty ?? false)
            _metaRow(Icons.location_on_outlined, group.locationDisplay!, isDark),
          if (group.meetingDisplay.isNotEmpty)
            _metaRow(Icons.schedule, group.meetingDisplay, isDark),
          if (group.leaderName?.isNotEmpty ?? false)
            _metaRow(
                Icons.person_outline,
                group.leaderPhone?.isNotEmpty == true
                    ? '${group.leaderName} · ${group.leaderPhone}'
                    : group.leaderName!,
                isDark),
        ],
      ),
    );
  }

  Widget _metaRow(IconData icon, String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(children: [
        Icon(icon, size: 13, color: AppColors.primary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text,
              style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white60 : Colors.black54)),
        ),
      ]),
    );
  }
}

class _MahderFormSheet extends StatefulWidget {
  final MahderatService service;
  final String atbiyaId;
  final String atbiyaName;
  final Mahder? existing;
  final bool isDark;
  final VoidCallback onSaved;

  const _MahderFormSheet({
    required this.service,
    required this.atbiyaId,
    required this.atbiyaName,
    required this.existing,
    required this.isDark,
    required this.onSaved,
  });

  @override
  State<_MahderFormSheet> createState() => _MahderFormSheetState();
}

class _MahderFormSheetState extends State<_MahderFormSheet> {
  late final TextEditingController _name;
  late final TextEditingController _nameAm;
  late final TextEditingController _location;
  late final TextEditingController _locationAm;
  late final TextEditingController _meetingTime;
  late final TextEditingController _leader;
  late final TextEditingController _leaderPhone;
  late final TextEditingController _description;
  String _meetingDay = '';
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name);
    _nameAm = TextEditingController(text: e?.nameAmharic);
    _location = TextEditingController(text: e?.locationLabel);
    _locationAm = TextEditingController(text: e?.locationLabelAm);
    _meetingTime = TextEditingController(text: e?.meetingTime);
    _leader = TextEditingController(text: e?.leaderName);
    _leaderPhone = TextEditingController(text: e?.leaderPhone);
    _description = TextEditingController(text: e?.description);
    _meetingDay = e?.meetingDay ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    _nameAm.dispose();
    _location.dispose();
    _locationAm.dispose();
    _meetingTime.dispose();
    _leader.dispose();
    _leaderPhone.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'The group needs a name.');
      return;
    }
    final rawPhone = _leaderPhone.text.trim();
    if (rawPhone.isNotEmpty && !isValidPhone(rawPhone)) {
      setState(() => _error = 'That leader phone number does not look right.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final data = widget.service.mahderPayload(
        name: name,
        nameAmharic: _nameAm.text,
        parentId: widget.atbiyaId,
        locationLabel: _location.text,
        locationLabelAm: _locationAm.text,
        meetingDay: _meetingDay,
        meetingTime: _meetingTime.text,
        leaderName: _leader.text,
        leaderPhone: normalizeEthiopianPhone(rawPhone) ?? rawPhone,
        description: _description.text,
      );
      if (widget.existing == null) {
        await widget.service.create(data);
      } else {
        await widget.service.update(widget.existing!.id, data);
      }
      if (mounted) Navigator.pop(context);
      widget.onSaved();
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Firestore denied that change, or it failed: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final isEditing = widget.existing != null;
    return FormSheet(
      title: isEditing
          ? 'Editing ${widget.existing!.name}'
          : 'New Mahedher',
      subtitle: 'A small Bible-study group in ${widget.atbiyaName}',
      isDark: isDark,
      saving: _saving,
      submitLabel: isEditing ? 'Save' : 'Create',
      onSubmit: _submit,
      children: [
        if (_error != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppColors.sacredRed.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(_error!,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.sacredRed)),
          ),
        buildLabel('Name (English) *', isDark),
        buildTextField(_name, 'e.g. Bole Mahder', isDark),
        const SizedBox(height: 16),
        buildLabel('Name (Amharic)', isDark),
        buildTextField(_nameAm, 'ቦሌ ማኅደር', isDark),
        const SizedBox(height: 16),
        buildLabel('Meeting day', isDark),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.grey.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: AppColors.primary.withValues(alpha: 0.12))),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value:
                  _meetingDay.isEmpty ? null : _meetingDay,
              hint: const Text('— Not set —',
                  style: TextStyle(fontSize: 13, color: Colors.grey)),
              items: [
                const DropdownMenuItem(value: '', child: Text('— Not set —')),
                ...kMeetingDays
                    .map((d) => DropdownMenuItem(value: d, child: Text(d))),
              ],
              onChanged: (v) => setState(() => _meetingDay = v ?? ''),
              isExpanded: true,
              dropdownColor:
                  isDark ? const Color(0xFF1A365D) : Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 16),
        buildLabel('Meeting time', isDark),
        buildTextField(_meetingTime, 'e.g. 10:00 AM', isDark),
        const SizedBox(height: 16),
        buildLabel('Landmark (English)', isDark),
        buildTextField(_location, 'e.g. near Bole Medhanealem', isDark),
        const SizedBox(height: 16),
        buildLabel('Landmark (Amharic)', isDark),
        buildTextField(_locationAm, 'ቦሌ መድኃኔዓለም አካባቢ', isDark),
        const SizedBox(height: 16),
        buildLabel('Leader', isDark),
        buildTextField(_leader, 'Leader name', isDark),
        const SizedBox(height: 16),
        buildLabel('Leader phone', isDark),
        buildTextField(_leaderPhone, '0911223344', isDark),
        const SizedBox(height: 16),
        buildLabel('Description', isDark),
        buildTextField(_description, 'Brief description...', isDark,
            maxLines: 3),
        const SizedBox(height: 8),
        Text(
          'Map pins are placed from the web — the pin decides which group is '
          'suggested to new members living nearby.',
          style: GoogleFonts.notoSansEthiopic(
              fontSize: 10, color: Colors.grey),
        ),
      ],
    );
  }
}

/// Read-only chooser shown to an approved member who has not joined a group
/// yet — the mobile port of ChooseMahderCard on the web dashboard.
///
/// Groups are ranked by distance from the member's saved home location when
/// one exists; pins come from the group document, which is why the pin on a
/// Mahder is public while a member's home location is not.
class ChooseMahderCard extends StatefulWidget {
  const ChooseMahderCard({super.key});

  @override
  State<ChooseMahderCard> createState() => _ChooseMahderCardState();
}

class _ChooseMahderCardState extends State<ChooseMahderCard> {
  final MahderatService _service = MahderatService();
  List<Mahder>? _groups;
  bool _loading = true;
  bool _saving = false;
  bool _dismissed = false;
  String? _error;
  String _choice = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = Provider.of<AuthService>(context, listen: false).userModel;
    final atbiyaId = user?.atbiyaId ?? '';
    if (atbiyaId.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    try {
      final groups = await _service.listByCongregation(atbiyaId);
      if (mounted) setState(() { _groups = groups; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _join(String mahderId) async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final user = auth.userModel;
    if (user == null || _saving) return;
    setState(() { _saving = true; _error = null; });
    try {
      await _service.joinAsMember(user.id, mahderId);
      await auth.refreshUser();
      if (mounted) setState(() => _dismissed = true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not join that group.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthService>(context).userModel;
    // Nothing to offer: not approved, no congregation, already in a group,
    // or the congregation has not created any.
    final applicable = user != null &&
        user.status == 'active' &&
        (user.atbiyaId ?? '').isNotEmpty &&
        user.mahderatId == null;
    if (!applicable || _dismissed || _loading) return const SizedBox.shrink();
    final groups = _groups ?? const [];
    if (groups.isEmpty) return const SizedBox.shrink();

    // Rank by distance from the member's saved home when we have both.
    final homeLat = (user.address?['lat'] as num?)?.toDouble();
    final homeLng = (user.address?['lng'] as num?)?.toDouble();
    final ranked = [...groups];
    final hasHome = homeLat != null && homeLng != null;
    if (hasHome) {
      ranked.sort((a, b) {
        final da = a.hasCoords
            ? MahderatService.distanceKm(homeLat, homeLng, a.lat!, a.lng!)
            : double.infinity;
        final db = b.hasCoords
            ? MahderatService.distanceKm(homeLat, homeLng, b.lat!, b.lng!)
            : double.infinity;
        return da.compareTo(db);
      });
    }
    if (_choice.isEmpty && ranked.isNotEmpty) _choice = ranked.first.id;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.75)]),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.groups, color: Colors.white, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Choose your Mahedher',
                  style: GoogleFonts.notoSansEthiopic(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Colors.white)),
            ),
          ]),
          const SizedBox(height: 6),
          Text(
            hasHome
                ? 'Small Bible-study groups in your congregation, nearest to you first.'
                : 'Small Bible-study groups in your congregation. Set where you live in your profile and we will show the closest one first.',
            style: GoogleFonts.notoSansEthiopic(
                fontSize: 12, color: Colors.white70),
          ),
          const SizedBox(height: 14),
          for (final g in ranked.take(5))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => setState(() => _choice = g.id),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: _choice == g.id
                        ? Colors.white.withValues(alpha: 0.18)
                        : Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: _choice == g.id
                            ? Colors.white
                            : Colors.white24),
                  ),
                  child: Row(children: [
                    Icon(
                        _choice == g.id
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        size: 18,
                        color: Colors.white),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(g.name,
                                style: GoogleFonts.notoSansEthiopic(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white)),
                            if (g.locationDisplay?.isNotEmpty ?? false)
                              Text(g.locationDisplay!,
                                  style: GoogleFonts.notoSansEthiopic(
                                      fontSize: 11, color: Colors.white70)),
                          ]),
                    ),
                    if (hasHome && g.hasCoords)
                      Text(
                        '${MahderatService.distanceKm(homeLat, homeLng, g.lat!, g.lng!).toStringAsFixed(1)} km',
                        style: GoogleFonts.notoSansEthiopic(
                            fontSize: 10, color: Colors.white70),
                      ),
                  ]),
                ),
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_error!,
                  style: const TextStyle(
                      fontSize: 11, color: Colors.white)),
            ),
          Row(children: [
            Expanded(
              child: TextButton(
                onPressed: _saving ? null : () => _join(_choice),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text('Join this Mahedher',
                        style: GoogleFonts.notoSansEthiopic(
                            fontSize: 13, fontWeight: FontWeight.w900)),
              ),
            ),
            const SizedBox(width: 10),
            TextButton(
              onPressed: () => setState(() => _dismissed = true),
              child: Text('Not now',
                  style: GoogleFonts.notoSansEthiopic(
                      fontSize: 12, color: Colors.white70)),
            ),
          ]),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1);
  }
}
