import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../services/auth_service.dart';
import '../../services/localization_service.dart';
import '../../services/permission_service.dart';
import '../../services/role_registry_service.dart';
import '../../services/org_unit_service.dart';
import '../../services/standing_synod_service.dart';
import '../../theme/app_colors.dart';
import '../../models/user_model.dart';
import 'announcements_page.dart' show buildLabel, buildTextField, FormSheet;

/// The whole organisational structure, one tab per level — the mobile port of
/// the web's Organisation page.
///
/// A single page rather than several sidebar entries: most levels differ only
/// in what they are called and what they hang off, so they share one registry
/// widget, and the drawer already carries twenty items.
///
/// The Standing Synod is the exception and keeps its own registry — membership
/// is the `KuamiSinodos` role on an account, not a hierarchy document. The
/// Mahderat tab is read-only here: groups are managed from the congregation
/// that owns them (My Atbiya → Mahedherat), matching the web.
class OrganisationPage extends StatefulWidget {
  const OrganisationPage({super.key});

  @override
  State<OrganisationPage> createState() => _OrganisationPageState();
}

class _OrganisationPageState extends State<OrganisationPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final OrgUnitService _org = OrgUnitService();

  /// Tab labels, resolved per build so a language change relabels them.
  List<String> _tabLabels(LocalizationService loc) => [
        loc.t('admin.tabStandingSynod'),
        loc.t('admin.tabSecretariat'),
        loc.t('admin.levelZone'),
        loc.t('admin.woreda'),
        loc.t('admin.levelAtbiya'),
        loc.t('admin.tabMahderat'),
      ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = Provider.of<LocalizationService>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final perms = Provider.of<PermissionService>(context);
    final registry = Provider.of<RoleRegistryService>(context);
    final level =
        Provider.of<AuthService>(context, listen: false).userModel?.hierarchyLevel;

    // Registering anything above a congregation is an isAdmin() action in
    // firestore.rules. Anyone who can see the hierarchy may read this page;
    // only an admin gets the write controls.
    final canEdit = perms.isSuperAdmin || registry.isAdminRole(level);

    Widget registryTab(String level, String? parentLevel,
            {String? childCountLevel}) =>
        _UnitRegistryTab(
          org: _org,
          level: level,
          parentLevel: parentLevel,
          childCountLevel: childCountLevel,
          canEdit: canEdit,
        );

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          loc.t('organisation'),
          style: GoogleFonts.notoSansEthiopic(
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : AppColors.lightText),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back,
              color: isDark ? Colors.white : AppColors.lightText),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppColors.primary,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          tabs: _tabLabels(loc).map((t) => Tab(text: t.toUpperCase())).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _StandingSynodTab(canEdit: canEdit),
          _SecretariatTab(org: _org, canEdit: canEdit),
          _ZoneTab(org: _org, canEdit: canEdit),
          registryTab('Woreda', 'Zone'),
          registryTab('Atbiya', 'Zone', childCountLevel: 'Mahderat'),
          _MahderatOverviewTab(org: _org),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Generic org-unit registry tab.
// ─────────────────────────────────────────────────────────────────────────────

class _UnitRegistryTab extends StatelessWidget {
  final OrgUnitService org;
  final String level;
  final String? parentLevel;
  /// When set, each card shows how many children of this level hang off it.
  final String? childCountLevel;
  final bool canEdit;

  const _UnitRegistryTab({
    required this.org,
    required this.level,
    required this.parentLevel,
    required this.childCountLevel,
    required this.canEdit,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<OrgUnit>>(
      stream: org.streamByLevel(level),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        if (snap.hasError) {
          return Center(
              child: Text('Could not load $level',
                  style: GoogleFonts.notoSansEthiopic(color: Colors.grey)));
        }
        final units = snap.data ?? const [];
        return Stack(children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            children: [
              if (units.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 60),
                  child: Column(children: [
                    Icon(Icons.business_outlined,
                        size: 64, color: AppColors.primary.withValues(alpha: 0.2)),
                    const SizedBox(height: 16),
                    Text(
                      'NO ${level.toUpperCase()}S YET',
                      style: GoogleFonts.notoSansEthiopic(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                          color: Colors.grey.withValues(alpha: 0.5)),
                    ),
                  ]),
                )
              else ...[
                if (childCountLevel != null)
                  _CountedCards(
                    org: org,
                    units: units,
                    childCountLevel: childCountLevel!,
                    canEdit: canEdit,
                    parentLevel: parentLevel,
                  )
                else
                  for (var i = 0; i < units.length; i++) ...[
                    _OrgUnitCard(
                          unit: units[i],
                          canEdit: canEdit,
                          org: org,
                          parentLevel: parentLevel,
                        )
                        .animate()
                        .fadeIn(delay: (i * 40).ms)
                        .slideY(begin: 0.08),
                    if (i < units.length - 1) const SizedBox(height: 12),
                  ],
              ],
            ],
          ),
          if (canEdit)
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton(
                backgroundColor: AppColors.primary,
                child:
                    const Icon(Icons.add_business_outlined, color: Colors.white),
                onPressed: () => _openSheet(context, null),
              ),
            ),
        ]);
      },
    );
  }

  void _openSheet(BuildContext context, OrgUnit? existing) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _UnitFormSheet(
        org: org,
        level: level,
        parentLevel: parentLevel,
        existing: existing,
        isDark: isDark,
      ),
    );
  }
}

/// Card list that also fetches child counts for badges, keyed by parent id.
class _CountedCards extends StatelessWidget {
  final OrgUnitService org;
  final List<OrgUnit> units;
  final String childCountLevel;
  final bool canEdit;
  final String? parentLevel;

  const _CountedCards({
    required this.org,
    required this.units,
    required this.childCountLevel,
    required this.canEdit,
    required this.parentLevel,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, int>>(
      future: org.childCounts(childCountLevel),
      builder: (context, snap) {
        final counts = snap.data ?? const <String, int>{};
        return Column(
          children: [
            for (var i = 0; i < units.length; i++) ...[
              _OrgUnitCard(
                    unit: units[i],
                    childCount: counts[units[i].id],
                    childCountLabel: childCountLevel,
                    canEdit: canEdit,
                    org: org,
                    parentLevel: parentLevel,
                  )
                  .animate()
                  .fadeIn(delay: (i * 40).ms)
                  .slideY(begin: 0.08),
              if (i < units.length - 1) const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }
}

/// One unit card with edit / hide-show actions.
class _OrgUnitCard extends StatelessWidget {
  final OrgUnit unit;
  final int? childCount;
  final String? childCountLabel;
  final bool canEdit;
  final OrgUnitService org;
  final String? parentLevel;

  const _OrgUnitCard({
    required this.unit,
    this.childCount,
    this.childCountLabel,
    required this.canEdit,
    required this.org,
    required this.parentLevel,
  });

  @override
  Widget build(BuildContext context) {
    final loc = Provider.of<LocalizationService>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Flexible(
                        child: Text(unit.name,
                            style: GoogleFonts.notoSansEthiopic(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color:
                                    isDark ? Colors.white : AppColors.lightText)),
                      ),
                      if (childCount != null && childCount! > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$childCount ${childCountLabel ?? ''}',
                            style: GoogleFonts.notoSansEthiopic(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary),
                          ),
                        ),
                      ],
                      if (!unit.active) ...[
                        const SizedBox(width: 8),
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
                      ],
                    ]),
                    if (unit.nameAmharic?.isNotEmpty ?? false)
                      Text(unit.nameAmharic!,
                          style: GoogleFonts.notoSansEthiopic(
                              fontSize: 13, color: Colors.grey[500])),
                  ],
                ),
              ),
              if (canEdit)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert,
                      color: AppColors.primary, size: 20),
                  onSelected: (v) async {
                    if (v == 'edit') {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => _UnitFormSheet(
                          org: org,
                          level: unit.level,
                          parentLevel: parentLevel,
                          existing: unit,
                          isDark: isDark,
                        ),
                      );
                    } else if (v == 'toggle') {
                      try {
                        await org.setActive(unit.id, !unit.active);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('Could not update: $e'),
                            backgroundColor: AppColors.sacredRed,
                            behavior: SnackBarBehavior.floating,
                          ));
                        }
                      }
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                        value: 'edit',
                        child: Row(children: [
                          const Icon(Icons.edit_outlined,
                              size: 16, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Text(loc.t('admin.edit')),
                        ])),
                    PopupMenuItem(
                        value: 'toggle',
                        child: Row(children: [
                          Icon(
                              unit.active
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: 16,
                              color: AppColors.primary),
                          const SizedBox(width: 8),
                          Text(unit.active ? loc.t('admin.hide') : loc.t('admin.show')),
                        ])),
                  ],
                ),
            ],
          ),
          if ((unit.location?.isNotEmpty ?? false) ||
              (unit.level != 'Atbiya' &&
                  (unit.leaderName?.isNotEmpty ?? false))) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                if (unit.location?.isNotEmpty ?? false)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.location_on_outlined,
                        size: 14, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(unit.location!,
                        style: TextStyle(
                            fontSize: 12,
                            color:
                                isDark ? Colors.white60 : Colors.black54)),
                  ]),
                // Not shown for a congregation: its leader belongs to the
                // private record, and anything on the public document is a
                // legacy value this app no longer writes.
                if (unit.level != 'Atbiya' &&
                    (unit.leaderName?.isNotEmpty ?? false))
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.person_outline,
                        size: 14, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(unit.leaderName!,
                        style: TextStyle(
                            fontSize: 12,
                            color:
                                isDark ? Colors.white60 : Colors.black54)),
                  ]),
              ],
            ),
          ],
          if (unit.description?.isNotEmpty ?? false) ...[
            const SizedBox(height: 8),
            Text(unit.description!,
                style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.grey[600]),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ],
        ],
      ),
    );
  }
}

/// Create/edit sheet for an org unit — mirrors the web registry's fields:
/// names, parent, leader, location, Ethiopian-calendar founded date.
class _UnitFormSheet extends StatefulWidget {
  final OrgUnitService org;
  final String level;
  final String? parentLevel;
  final OrgUnit? existing;
  final bool isDark;

  const _UnitFormSheet({
    required this.org,
    required this.level,
    required this.parentLevel,
    required this.existing,
    required this.isDark,
  });

  @override
  State<_UnitFormSheet> createState() => _UnitFormSheetState();
}

class _UnitFormSheetState extends State<_UnitFormSheet> {
  late final TextEditingController _name;
  late final TextEditingController _nameAm;
  late final TextEditingController _leader;
  late final TextEditingController _leaderPhone;
  late final TextEditingController _location;
  late final TextEditingController _desc;
  late final TextEditingController _founded;
  String? _parentId;
  bool _saving = false;
  String? _error;

  bool get _needsParent => widget.parentLevel != null;

  LocalizationService get loc =>
      Provider.of<LocalizationService>(context, listen: false);

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name);
    _nameAm = TextEditingController(text: e?.nameAmharic);
    _leader = TextEditingController(text: e?.leaderName);
    _leaderPhone = TextEditingController(text: e?.leaderPhone);
    _location = TextEditingController(text: e?.location);
    _desc = TextEditingController(text: e?.description);
    _founded = TextEditingController(text: e?.foundedAt);
    _parentId = e?.parentId;
    // A congregation's leader lives in atbiyaPrivate.contact, not on the
    // public document, so it has to be fetched before the form can show it —
    // otherwise saving would overwrite it with an empty box.
    if (e != null && widget.level == 'Atbiya') _loadContact(e.id);
  }

  Future<void> _loadContact(String id) async {
    final private = await widget.org.getAtbiyaPrivate(id);
    final contact = (private['contact'] as Map?) ?? const {};
    if (!mounted) return;
    setState(() {
      // Legacy records still carry the leader on the public document; prefer
      // the private block once it exists.
      final name = (contact['nameEn'] as String?) ?? '';
      final phone = (contact['phone'] as String?) ?? '';
      if (name.isNotEmpty) _leader.text = name;
      if (phone.isNotEmpty) _leaderPhone.text = phone;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _nameAm.dispose();
    _leader.dispose();
    _leaderPhone.dispose();
    _location.dispose();
    _desc.dispose();
    _founded.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = loc.t('admin.unitNameRequired'));
      return;
    }
    if (_needsParent && (_parentId == null || _parentId!.isEmpty)) {
      setState(() => _error = 'Select the ${widget.parentLevel} it hangs off.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      final data = OrgUnitService.unitPayload(
        name: _name.text,
        level: widget.level,
        nameAmharic: _nameAm.text,
        parentId: _parentId,
        leaderName: _leader.text,
        leaderPhone: _leaderPhone.text,
        location: _location.text,
        description: _desc.text,
        foundedAt: _founded.text,
      );
      // A congregation's leader details belong in atbiyaPrivate, not in the
      // world-readable /hierarchy document — see unitPayload.
      final isAtbiya = widget.level == 'Atbiya';
      if (widget.existing == null) {
        final id = await widget.org.create(widget.level, data);
        if (isAtbiya) {
          await widget.org.updateAtbiya(
              id,
              OrgUnitService.atbiyaContact(
                  leaderName: _leader.text, leaderPhone: _leaderPhone.text));
        }
      } else {
        // level never changes; parentId only when the level allows one.
        final payload = {...data};
        if (!_needsParent) payload.remove('parentId');
        if (isAtbiya) {
          await widget.org.updateAtbiya(widget.existing!.id, {
            ...payload,
            ...OrgUnitService.atbiyaContact(
                leaderName: _leader.text, leaderPhone: _leaderPhone.text),
          });
        } else {
          await widget.org.update(widget.existing!.id, payload);
        }
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() { _saving = false; _error = 'Failed: $e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final isEditing = widget.existing != null;
    return FormSheet(
      title: isEditing
          ? '${loc.t('admin.edit')} ${widget.level}'
          : '${loc.t('admin.create')} ${widget.level}',
      subtitle: loc.t('admin.orgUnitSubtitle'),
      isDark: isDark,
      saving: _saving,
      submitLabel: isEditing ? loc.t('admin.save') : loc.t('admin.create'),
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
        buildTextField(_name, 'e.g. East Shewa Zone', isDark),
        const SizedBox(height: 16),
        buildLabel(loc.t('admin.nameAmharic'), isDark),
        buildTextField(_nameAm, 'e.g. ምስራቅ ሸዋ ዞን', isDark),
        const SizedBox(height: 16),
        if (_needsParent) ...[
          buildLabel('Parent ${widget.parentLevel} *', isDark),
          _ParentDropdown(
            org: widget.org,
            parentLevel: widget.parentLevel!,
            selectedId: _parentId,
            onChanged: (v) => setState(() => _parentId = v),
            isDark: isDark,
          ),
          const SizedBox(height: 16),
        ],
        buildLabel(loc.t('admin.leaderName'), isDark),
        buildTextField(_leader, 'e.g. Tesfaye Bekele', isDark),
        const SizedBox(height: 16),
        buildLabel(loc.t('admin.leaderPhone'), isDark),
        buildTextField(_leaderPhone, '+251911223344', isDark),
        const SizedBox(height: 16),
        buildLabel(loc.t('admin.location'), isDark),
        buildTextField(_location, 'e.g. Addis Ababa', isDark),
        const SizedBox(height: 16),
        buildLabel(loc.t('admin.foundedAt'), isDark),
        buildTextField(_founded, 'e.g. 2017 ዓ.ም', isDark),
        const SizedBox(height: 16),
        buildLabel(loc.t('admin.entityDescription'), isDark),
        buildTextField(_desc, loc.t('admin.entityDescPlaceholder'), isDark, maxLines: 3),
      ],
    );
  }
}

/// Parent picker backed by a live stream of the parent level.
class _ParentDropdown extends StatelessWidget {
  final OrgUnitService org;
  final String parentLevel;
  final String? selectedId;
  final ValueChanged<String?> onChanged;
  final bool isDark;

  const _ParentDropdown({
    required this.org,
    required this.parentLevel,
    required this.selectedId,
    required this.onChanged,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<OrgUnit>>(
      stream: org.streamByLevel(parentLevel),
      builder: (context, snapshot) {
        final items = snapshot.data ?? const [];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.grey.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.12))),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: (selectedId != null &&
                      items.any((e) => e.id == selectedId))
                  ? selectedId
                  : null,
              hint: Text('Select $parentLevel',
                  style: const TextStyle(fontSize: 13, color: Colors.grey)),
              items: items
                  .map((e) =>
                      DropdownMenuItem(value: e.id, child: Text(e.name)))
                  .toList(),
              onChanged: onChanged,
              isExpanded: true,
              dropdownColor:
                  isDark ? const Color(0xFF1A365D) : Colors.white,
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Secretariat tab — the ጠቅላይ ጽሕፈት ቤት singleton plus the departments under it.
// ─────────────────────────────────────────────────────────────────────────────

class _SecretariatTab extends StatelessWidget {
  final OrgUnitService org;
  final bool canEdit;

  const _SecretariatTab({required this.org, required this.canEdit});

  @override
  Widget build(BuildContext context) {
    final loc = Provider.of<LocalizationService>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return StreamBuilder<List<OrgUnit>>(
      stream: org.streamByLevel('Teklay'),
      builder: (context, snap) {
        final list = snap.data ?? const <OrgUnit>[];
        final secretariat = list.isEmpty ? null : list.first;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _SectionCard(
              title: loc.t('admin.levelTeklayOne'),
              description: secretariat == null
                  ? loc.t('admin.secretariatNoneDesc')
                  : loc.t('admin.orgDesc'),
              isDark: isDark,
            ),
            const SizedBox(height: 10),
            _EmbeddedRegistry(
                org: org,
                level: 'Teklay',
                parentLevel: null,
                canEdit: canEdit,
                emptyLabel: loc.t('admin.noSecretariatYet').toUpperCase()),
            const SizedBox(height: 20),
            _SectionCard(
              title: loc.t('admin.levelMemriya'),
              description: loc.t('admin.deptUnderSecretariat'),
              isDark: isDark,
            ),
            const SizedBox(height: 10),
            _EmbeddedRegistry(
                org: org,
                level: 'Memriya',
                parentLevel: 'Teklay',
                canEdit: canEdit,
                emptyLabel: loc.t('admin.noDepartmentsYet').toUpperCase()),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dioceses tab — the Zone registry plus which congregations sit under each.
// ─────────────────────────────────────────────────────────────────────────────

class _ZoneTab extends StatelessWidget {
  final OrgUnitService org;
  final bool canEdit;

  const _ZoneTab({required this.org, required this.canEdit});

  @override
  Widget build(BuildContext context) {
    final loc = Provider.of<LocalizationService>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _SectionCard(
          title: loc.t('admin.levelZone'),
          description:
              'ሀገረ ስብከት offices. Congregations are managed in the Congregations tab.',
          isDark: isDark,
        ),
        const SizedBox(height: 10),
        _EmbeddedRegistry(
            org: org,
            level: 'Zone',
            parentLevel: 'Teklay',
            canEdit: canEdit,
            emptyLabel: loc.t('admin.noDiocesesYet').toUpperCase()),
        const SizedBox(height: 20),
        _SectionCard(
          title: loc.t('admin.atbiyaUnderDiocese'),
          description:
              loc.t('admin.diocesePlacementDesc'),
          isDark: isDark,
        ),
        const SizedBox(height: 10),
        _DiocesePlacement(org: org),
      ],
    );
  }
}

/// A section header (title + description above the cards).
class _SectionCard extends StatelessWidget {
  final String title;
  final String description;
  final bool isDark;

  const _SectionCard({
    required this.title,
    required this.description,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: GoogleFonts.notoSansEthiopic(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : AppColors.lightText)),
        const SizedBox(height: 4),
        Text(description,
            style: GoogleFonts.notoSansEthiopic(
                fontSize: 11,
                color: isDark ? Colors.white54 : Colors.grey[600])),
      ],
    );
  }
}

/// A shrink-wrapped, non-scrolling registry card list for embedding in a
/// sectioned tab. Shows an inline add button when [canEdit].
class _EmbeddedRegistry extends StatelessWidget {
  final OrgUnitService org;
  final String level;
  final String? parentLevel;
  final bool canEdit;
  final String emptyLabel;

  const _EmbeddedRegistry({
    required this.org,
    required this.level,
    required this.parentLevel,
    required this.canEdit,
    required this.emptyLabel,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return StreamBuilder<List<OrgUnit>>(
      stream: org.streamByLevel(level),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(strokeWidth: 2),
          ));
        }
        final units = snap.data ?? const [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (units.isEmpty)
              Text(emptyLabel,
                  style: GoogleFonts.notoSansEthiopic(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      color: Colors.grey.withValues(alpha: 0.5)))
            else
              for (var i = 0; i < units.length; i++) ...[
                _OrgUnitCard(
                    unit: units[i],
                    canEdit: canEdit,
                    org: org,
                    parentLevel: parentLevel),
                if (i < units.length - 1) const SizedBox(height: 10),
              ],
            if (canEdit) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => _UnitFormSheet(
                    org: org,
                    level: level,
                    parentLevel: parentLevel,
                    existing: null,
                    isDark: isDark,
                  ),
                ),
                icon: const Icon(Icons.add, size: 16, color: AppColors.primary),
                label: Text('Add $level',
                    style: GoogleFonts.notoSansEthiopic(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary)),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Which congregations sit under each Diocese, and which sit under none.
class _DiocesePlacement extends StatelessWidget {
  final OrgUnitService org;

  const _DiocesePlacement({required this.org});

  @override
  Widget build(BuildContext context) {
    final loc = Provider.of<LocalizationService>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return StreamBuilder<List<OrgUnit>>(
      stream: org.streamByLevel('Zone'),
      builder: (context, zoneSnap) {
        return StreamBuilder<List<OrgUnit>>(
          stream: org.streamByLevel('Atbiya'),
          builder: (context, atbiyaSnap) {
            if (zoneSnap.connectionState == ConnectionState.waiting ||
                atbiyaSnap.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child:
                    Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }
            final dioceses = zoneSnap.data ?? const [];
            final congregations = atbiyaSnap.data ?? const [];
            final groups = [
              for (final d in dioceses)
                (
                  label:
                      d.nameAmharic?.isNotEmpty == true ? d.nameAmharic! : d.name,
                  items: congregations.where((c) => c.parentId == d.id).toList(),
                ),
              (
                label: '— Not assigned —',
                items: congregations
                    .where((c) =>
                        c.parentId == null ||
                        c.parentId!.isEmpty ||
                        !dioceses.any((d) => d.id == c.parentId))
                    .toList(),
              ),
            ].where((g) => g.items.isNotEmpty).toList();

            if (groups.isEmpty) {
              return Text(loc.t('admin.noCongregationsYet'),
                  style: GoogleFonts.notoSansEthiopic(
                      fontSize: 12, color: Colors.grey));
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final g in groups) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6, top: 4),
                    child: Text(
                      '${g.label} (${g.items.length})',
                      style: GoogleFonts.notoSansEthiopic(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary),
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      for (final c in g.items)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: AppColors.primary
                                    .withValues(alpha: 0.15)),
                          ),
                          child: Text(c.name,
                              style: GoogleFonts.notoSansEthiopic(
                                  fontSize: 11,
                                  color: isDark
                                      ? Colors.white70
                                      : AppColors.lightText)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mahderat overview — every group in the church, grouped by congregation.
// Read-only: editing happens from the owning congregation (My Atbiya).
// ─────────────────────────────────────────────────────────────────────────────

class _MahderatOverviewTab extends StatelessWidget {
  final OrgUnitService org;

  const _MahderatOverviewTab({required this.org});

  @override
  Widget build(BuildContext context) {
    final loc = Provider.of<LocalizationService>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return StreamBuilder<List<OrgUnit>>(
      stream: org.streamByLevel('Atbiya'),
      builder: (context, atbiyaSnap) {
        return StreamBuilder<List<OrgUnit>>(
          stream: org.streamByLevel('Mahderat'),
          builder: (context, mahderSnap) {
            if (atbiyaSnap.connectionState == ConnectionState.waiting ||
                mahderSnap.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(strokeWidth: 2));
            }
            final congregations = atbiyaSnap.data ?? const [];
            final groups = mahderSnap.data ?? const [];
            if (congregations.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    loc.t('admin.noCongregationsForMahderat'),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.notoSansEthiopic(
                        fontSize: 13, color: Colors.grey),
                  ),
                ),
              );
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final c in congregations)
                  if (groups.any((m) => m.parentId == c.id)) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 6),
                      child: Text(
                        c.nameAmharic?.isNotEmpty == true
                            ? '${c.nameAmharic} · ${c.name}'
                            : c.name,
                        style: GoogleFonts.notoSansEthiopic(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary),
                      ),
                    ),
                    for (final m in groups.where((m) => m.parentId == c.id))
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.04)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.08)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.groups_outlined,
                              size: 16, color: AppColors.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(m.name,
                                      style: GoogleFonts.notoSansEthiopic(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: isDark
                                              ? Colors.white
                                              : AppColors.lightText)),
                                  if (m.meetingDisplay.isNotEmpty)
                                    Text(m.meetingDisplay,
                                        style: GoogleFonts.notoSansEthiopic(
                                            fontSize: 11, color: Colors.grey)),
                                ]),
                          ),
                          if (!m.hasCoords)
                            Text(loc.t('admin.noPin').toUpperCase(),
                                style: GoogleFonts.notoSansEthiopic(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1,
                                    color: Colors.amber[700])),
                          if (!m.active) ...[
                            const SizedBox(width: 8),
                            Text('HIDDEN',
                                style: GoogleFonts.notoSansEthiopic(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1,
                                    color: Colors.grey)),
                          ],
                        ]),
                      ),
                  ],
              ],
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Standing Synod registry — membership is the KuamiSinodos role on an account.
// ─────────────────────────────────────────────────────────────────────────────

class _StandingSynodTab extends StatefulWidget {
  final bool canEdit;

  const _StandingSynodTab({required this.canEdit});

  @override
  State<_StandingSynodTab> createState() => _StandingSynodTabState();
}

class _StandingSynodTabState extends State<_StandingSynodTab> {
  final StandingSynodService _synod = StandingSynodService();
  List<UserModel>? _members;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final members = await _synod.list();
      if (mounted) {
        setState(() {
          _members = members;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addMember() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SynodAddSheet(
        synod: _synod,
        existing: _members ?? const [],
        isDark: isDark,
        onSaved: _load,
      ),
    );
  }

  Future<void> _removeMember(UserModel m) async {
    final registry = Provider.of<RoleRegistryService>(context, listen: false);
    final loc =
        Provider.of<LocalizationService>(context, listen: false);
    final roles = _synod.ordinaryRoles(registry);
    final fallback = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${StandingSynodService.nameOf(m)}'),
        content: Text(
            'Where does ${StandingSynodService.nameOf(m)} go? They stay a member of the church — only their Standing Synod seat changes.'),
        actions: [
          for (final r in roles)
            TextButton(
              onPressed: () => Navigator.pop(ctx, r),
              child: Text(registry.roleLabel(r, loc.language)),
            ),
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(loc.t('admin.cancel'))),
        ],
      ),
    );
    if (fallback == null || !mounted) return;
    try {
      await _synod.remove(m.id, StandingSynodService.nameOf(m), fallback);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not remove: $e'),
          backgroundColor: AppColors.sacredRed,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = Provider.of<LocalizationService>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final members = _members ?? const [];
    final overCapacity = members.length > kStandingSynodSeats;
    return Stack(children: [
      ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
        children: [
          Row(children: [
            Text('${members.length} / $kStandingSynodSeats seats',
                style: GoogleFonts.notoSansEthiopic(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color:
                        overCapacity ? Colors.amber[700] : AppColors.primary)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                loc.t('admin.synodMembershipNote'),
                style: GoogleFonts.notoSansEthiopic(
                    fontSize: 10, color: Colors.grey),
              ),
            ),
          ]),
          const SizedBox(height: 14),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(40),
              child:
                  Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (members.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 50),
              child: Column(children: [
                Icon(Icons.account_balance_outlined,
                    size: 64, color: AppColors.primary.withValues(alpha: 0.2)),
                const SizedBox(height: 16),
                Text(loc.t('admin.noMembersYet').toUpperCase(),
                    style: GoogleFonts.notoSansEthiopic(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        color: Colors.grey.withValues(alpha: 0.5))),
              ]),
            )
          else
            for (var i = 0; i < members.length; i++) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.08)),
                ),
                child: Row(children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor:
                        AppColors.primary.withValues(alpha: 0.12),
                    child: Text(
                      StandingSynodService.nameOf(members[i]).isNotEmpty
                          ? StandingSynodService
                              .nameOf(members[i])[0]
                              .toUpperCase()
                          : '?',
                      style: GoogleFonts.notoSansEthiopic(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(StandingSynodService.nameOf(members[i]),
                              style: GoogleFonts.notoSansEthiopic(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? Colors.white
                                      : AppColors.lightText)),
                          if (members[i].email.isNotEmpty)
                            Text(members[i].email,
                                style: GoogleFonts.notoSansEthiopic(
                                    fontSize: 11, color: Colors.grey)),
                        ]),
                  ),
                  if (widget.canEdit)
                    IconButton(
                      icon: const Icon(Icons.logout,
                          size: 18, color: AppColors.sacredRed),
                      tooltip: loc.t('admin.synodRemoveFrom'),
                      onPressed: () => _removeMember(members[i]),
                    ),
                ]),
              ).animate().fadeIn(delay: (i * 40).ms),
            ],
        ],
      ),
      if (widget.canEdit)
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            backgroundColor: AppColors.primary,
            onPressed: _addMember,
            child: const Icon(Icons.person_add_alt, color: Colors.white),
          ),
        ),
    ]);
  }
}

/// Add-to-synod sheet: pick an existing account that is not already a member.
class _SynodAddSheet extends StatefulWidget {
  final StandingSynodService synod;
  final List<UserModel> existing;
  final bool isDark;
  final void Function() onSaved;

  const _SynodAddSheet({
    required this.synod,
    required this.existing,
    required this.isDark,
    required this.onSaved,
  });

  @override
  State<_SynodAddSheet> createState() => _SynodAddSheetState();
}

class _SynodAddSheetState extends State<_SynodAddSheet> {
  final TextEditingController _search = TextEditingController();
  List<UserModel>? _candidates;
  String _pick = '';
  bool _saving = false;
  String? _error;

  LocalizationService get loc =>
      Provider.of<LocalizationService>(context, listen: false);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('users').get();
      final memberIds = widget.existing.map((m) => m.id).toSet();
      final candidates = snap.docs
          .map((d) => UserModel.fromFirestore(
              d.id, d.data(), (d.data()['email'] ?? '') as String))
          .where((u) => !memberIds.contains(u.id))
          .toList()
        ..sort((a, b) => StandingSynodService.nameOf(a)
            .toLowerCase()
            .compareTo(StandingSynodService.nameOf(b).toLowerCase()));
      if (mounted) setState(() => _candidates = candidates);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not load members: $e');
    }
  }

  Future<void> _submit() async {
    if (_pick.isEmpty) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final chosen = _candidates!.firstWhere(
        (c) => c.id == _pick,
        orElse: () => _candidates!.first,
      );
      await widget.synod.add(chosen.id, StandingSynodService.nameOf(chosen));
      if (mounted) Navigator.pop(context);
      widget.onSaved();
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Failed: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final all = _candidates ?? const [];
    return FormSheet(
      title: loc.t('admin.synodConfirmAdd'),
      subtitle: 'Nine seats by the bylaws; overlap during a handover is fine.',
      isDark: isDark,
      saving: _saving,
      submitLabel: loc.t('pages.addMember'),
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
        buildLabel(loc.t('admin.searchMembers'), isDark),
        buildTextField(_search, loc.t('admin.searchNamePlaceholder'), isDark),
        const SizedBox(height: 8),
        // Rebuilds the filtered list live while typing — the field writes
        // straight into _search, so listening to it is enough.
        AnimatedBuilder(
          animation: _search,
          builder: (context, _) {
            final q = _search.text.trim().toLowerCase();
            final list = q.isEmpty
                ? all
                : all
                    .where((c) =>
                        StandingSynodService.nameOf(c)
                            .toLowerCase()
                            .contains(q) ||
                        c.email.toLowerCase().contains(q))
                    .toList();
            if (_candidates == null) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child:
                    Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }
            if (list.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Text(loc.t('admin.synodNoMatch'),
                    style: GoogleFonts.notoSansEthiopic(
                        fontSize: 12, color: Colors.grey)),
              );
            }
            return Column(
              children: [
                for (final c in list.take(30))
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                        _pick == c.id
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        size: 20,
                        color: _pick == c.id
                            ? AppColors.primary
                            : Colors.grey),
                    title: Text(StandingSynodService.nameOf(c),
                        style: GoogleFonts.notoSansEthiopic(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? Colors.white
                                : AppColors.lightText)),
                    subtitle: Text(c.email,
                        style: GoogleFonts.notoSansEthiopic(
                            fontSize: 11, color: Colors.grey)),
                    onTap: () => setState(() => _pick = c.id),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
