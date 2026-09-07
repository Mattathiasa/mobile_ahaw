import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../../services/member_service.dart';
import '../../services/auth_service.dart';
import '../../services/permission_service.dart';
import '../../services/role_registry_service.dart';
import '../../services/module_config_service.dart';
import '../../services/cloudinary_service.dart';
import '../../widgets/image_upload_field.dart';
import '../../theme/app_colors.dart';
import 'package:flutter_animate/flutter_animate.dart';

class MembersPage extends StatefulWidget {
  const MembersPage({super.key});

  @override
  State<MembersPage> createState() => _MembersPageState();
}

class _MembersPageState extends State<MembersPage> {
  final MemberService _memberService = MemberService();
  String _searchQuery = '';
  String _filterHierarchy = 'all';
  final String _sortBy = 'name';
  late Future<List<Map<String, dynamic>>> _membersFuture;

  final List<String> _hierarchyLevels = [
    'Sinodos',
    'KuamiSinodos',
    'Memriya',
    'Zone',
    'Atbiya',
    'EnkesekaseMaikel',
    'HiyawanMahderat'
  ];

  @override
  void initState() {
    super.initState();
    _membersFuture = _load();
  }

  /// Scope the directory read to what firestore.rules allows for this user
  /// (head office / diocese see everyone; a parish sees only its own members).
  MemberScope _computeScope() {
    final auth = Provider.of<AuthService>(context, listen: false);
    final perms = Provider.of<PermissionService>(context, listen: false);
    final registry = Provider.of<RoleRegistryService>(context, listen: false);
    final user = auth.userModel;
    return registry.memberScopeFor(
      roleKey: user?.hierarchyLevel,
      isSuperAdmin: perms.isSuperAdmin,
      atbiyaId: user?.parishId ?? '',
    );
  }

  Future<List<Map<String, dynamic>>> _load() {
    final scope = _computeScope();
    return _memberService.getMembersInScope(
      wholeDirectory: scope.wholeDirectory,
      atbiyaId: scope.atbiyaId,
    );
  }

  void _reload() => setState(() => _membersFuture = _load());

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
          'Church Members',
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
      body: Column(
        children: [
          _buildSearchAndFilters(context, surfaceColor, isDark),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _membersFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text("Error: ${snapshot.error}"));
                }

                final members = snapshot.data ?? [];
                final filteredMembers = _getFilteredAndSortedMembers(members);

                if (filteredMembers.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: filteredMembers.length,
                  itemBuilder: (context, index) {
                    return _buildMemberCard(context, filteredMembers[index], index, surfaceColor, isDark);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Provider.of<PermissionService>(context).can('canAddMembers')
          ? (FloatingActionButton(
              onPressed: () => _openMemberForm(context),
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add, color: Colors.white),
            ).animate().scale(delay: 500.ms))
          : null,
    );
  }

  Widget _buildSearchAndFilters(BuildContext context, Color surfaceColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor.withOpacity(0.3),
        border: Border(bottom: BorderSide(color: AppColors.primary.withOpacity(0.1))),
      ),
      child: Column(
        children: [
          Container(
            height: 45,
            decoration: BoxDecoration(
              color: isDark ? Colors.black26 : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withOpacity(0.1)),
            ),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              style: GoogleFonts.notoSansEthiopic(fontSize: 13),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search, color: AppColors.primary, size: 18),
                hintText: 'Search members...',
                hintStyle: GoogleFonts.notoSansEthiopic(fontSize: 13, color: Colors.grey),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 32,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildFilterChip('All', 'all', _filterHierarchy == 'all', (val) => setState(() => _filterHierarchy = val)),
                ..._hierarchyLevels.map((lvl) => _buildFilterChip(lvl, lvl, _filterHierarchy == lvl, (val) => setState(() => _filterHierarchy = val))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, bool isSelected, Function(String) onSelected) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: () => onSelected(value),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : AppColors.primary.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isSelected ? Colors.transparent : AppColors.primary.withOpacity(0.1)),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.notoSansEthiopic(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: isSelected ? Colors.white : AppColors.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getFilteredAndSortedMembers(List<Map<String, dynamic>> members) {
    return members.where((m) {
      final name = ((m['fullNameEnglish'] ?? m['fullName'] ?? '').toString()).toLowerCase();
      final nameAm = (m['fullNameAmharic'] ?? '').toString().toLowerCase();
      final matchesSearch = name.contains(_searchQuery.toLowerCase()) || nameAm.contains(_searchQuery.toLowerCase());
      final matchesHierarchy = _filterHierarchy == 'all' || m['hierarchyLevel'] == _filterHierarchy;
      return matchesSearch && matchesHierarchy;
    }).toList()
      ..sort((a, b) {
        if (_sortBy == 'name') {
          return (a['fullNameEnglish'] ?? a['fullName'] ?? '').toString().compareTo((b['fullNameEnglish'] ?? b['fullName'] ?? '').toString());
        }
        return 0;
      });
  }

  Widget _buildMemberCard(BuildContext context, Map<String, dynamic> member, int index, Color surfaceColor, bool isDark) {
    final name = member['fullNameEnglish'] ?? member['fullName'] ?? 'Unknown Member';
    final nameAm = member['fullNameAmharic'] ?? '';
    final hierarchy = member['hierarchyLevel'] ?? 'Member';
    final initials = name.split(' ').where((e) => e.isNotEmpty).map((e) => e[0].toUpperCase()).join('');

    return Container(
      margin: const EdgeInsets.only(bottom: 10, left: 16, right: 16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.05)),
      ),
      child: InkWell(
        onTap: () => _showMemberDetails(context, member, isDark),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    initials.isNotEmpty ? (initials.length > 2 ? initials.substring(0, 2) : initials) : 'U',
                    style: GoogleFonts.notoSansEthiopic(fontWeight: FontWeight.w900, color: AppColors.primary, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.notoSansEthiopic(fontWeight: FontWeight.w900, fontSize: 14, color: isDark ? Colors.white : AppColors.lightText),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (nameAm.isNotEmpty)
                      Text(
                        nameAm,
                        style: GoogleFonts.notoSansEthiopic(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w900),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  hierarchy.toUpperCase(),
                  style: GoogleFonts.notoSansEthiopic(fontSize: 8, fontWeight: FontWeight.w900, color: AppColors.primary, letterSpacing: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: (index * 30).ms).slideX(begin: 0.05);
  }

  void _showMemberDetails(BuildContext context, Map<String, dynamic> member, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkBackground : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
        ),
        padding: const EdgeInsets.all(30),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 60,
                  height: 6,
                  decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(3)),
                ),
              ),
              const SizedBox(height: 30),
              Builder(builder: (context) {
                final pic = (member['profilePicture'] as String?) ?? '';
                return Center(
                  child: CircleAvatar(
                    radius: 60,
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    backgroundImage: pic.isNotEmpty
                        ? NetworkImage(
                            CloudinaryService.optimized(pic, width: 240))
                        : null,
                    child: pic.isEmpty
                        ? Text(
                            (member['fullNameEnglish'] ?? 'U')[0],
                            style: GoogleFonts.notoSansEthiopic(
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary),
                          )
                        : null,
                  ),
                );
              }),
              const SizedBox(height: 20),
              Center(
                child: Column(
                  children: [
                    Text(
                      member['fullNameEnglish'] ?? member['fullName'] ?? 'Unknown',
                      style: GoogleFonts.notoSansEthiopic(fontSize: 24, fontWeight: FontWeight.w900),
                    ),
                    Text(
                      member['fullNameAmharic'] ?? '',
                      style: GoogleFonts.notoSansEthiopic(fontSize: 18, color: AppColors.primary, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              const Divider(),
              const SizedBox(height: 20),
              _buildDetailItem(FontAwesomeIcons.envelope, 'Email', member['email'] ?? 'No email'),
              _buildDetailItem(FontAwesomeIcons.phone, 'Phone', member['phone'] ?? 'No phone'),
              _buildDetailItem(FontAwesomeIcons.networkWired, 'Hierarchy', member['hierarchyLevel'] ?? 'None'),
              _buildDetailItem(FontAwesomeIcons.mapLocationDot, 'Region', member['address']?['region'] ?? 'None'),
              _buildDetailItem(FontAwesomeIcons.city, 'Zone', member['address']?['zone'] ?? 'None'),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (Provider.of<PermissionService>(context, listen: false)
                      .can('canEditMembers'))
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _openMemberForm(context, member: member);
                        },
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('Edit'),
                      ),
                    ),
                  if (Provider.of<PermissionService>(context, listen: false)
                      .can('canDeleteMembers')) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.sacredRed),
                        onPressed: () async {
                          Navigator.pop(context);
                          await _confirmSuspend(member);
                        },
                        icon: const Icon(Icons.block, size: 16),
                        label: const Text('Suspend'),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmSuspend(Map<String, dynamic> member) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Suspend member?'),
        content: Text(
            'This suspends ${member['fullNameEnglish'] ?? member['fullName'] ?? 'this member'} and revokes their access.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Suspend',
                  style: TextStyle(color: AppColors.sacredRed))),
        ],
      ),
    );
    if (ok == true) {
      await _memberService.suspendMember(member['id'] as String);
      _reload();
    }
  }

  /// Create or edit a member. Creation makes a real Auth account (via
  /// member_service), so username + password are required; edit updates the
  /// Firestore profile only.
  void _openMemberForm(BuildContext context, {Map<String, dynamic>? member}) {
    final isEditing = member != null;
    final moduleConfig =
        Provider.of<ModuleConfigService>(context, listen: false);
    final creator =
        Provider.of<AuthService>(context, listen: false).userModel;

    final usernameCtrl = TextEditingController(text: member?['username']);
    final passwordCtrl = TextEditingController();
    final fullNameCtrl = TextEditingController(
        text: member?['fullNameEnglish'] ?? member?['fullName']);
    final fullNameAmCtrl =
        TextEditingController(text: member?['fullNameAmharic']);
    final phoneCtrl = TextEditingController(text: member?['phone']);
    final emailCtrl = TextEditingController(text: member?['email']);
    String gender = member?['gender']?.toString() ??
        (moduleConfig.options('members', 'genders').isNotEmpty
            ? moduleConfig.options('members', 'genders').first
            : 'Male');
    String level = member?['hierarchyLevel']?.toString() ?? 'HiyawanMahderat';
    String profileUrl = member?['profilePicture']?.toString() ?? '';
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
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
                    Text(isEditing ? 'Edit Member' : 'New Member',
                        style: GoogleFonts.notoSansEthiopic(
                            fontSize: 18, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 16),
                    Center(
                      child: ImageUploadField(
                        initialUrl: profileUrl,
                        folder: 'members',
                        label: 'Profile photo',
                        onUploaded: (url) => profileUrl = url,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _field(fullNameCtrl, 'Full Name (English)', required: true),
                    _field(fullNameAmCtrl, 'Full Name (Amharic)'),
                    _field(phoneCtrl, 'Phone',
                        keyboardType: TextInputType.phone),
                    if (!isEditing) ...[
                      _field(emailCtrl, 'Email (optional)',
                          keyboardType: TextInputType.emailAddress),
                      _field(usernameCtrl, 'Username', required: true),
                      _field(passwordCtrl, 'Password (min 6)',
                          required: true, obscure: true),
                    ],
                    _dropdown('Gender', gender,
                        moduleConfig.options('members', 'genders'),
                        (v) => setSheet(() => gender = v)),
                    _dropdown('Hierarchy Level', level, _hierarchyLevels,
                        (v) => setSheet(() => level = v)),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 14)),
                        onPressed: saving
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                setSheet(() => saving = true);
                                try {
                                  if (isEditing) {
                                    await _memberService.updateMember(
                                        member['id'] as String, {
                                      'fullNameEnglish': fullNameCtrl.text.trim(),
                                      'fullNameAmharic':
                                          fullNameAmCtrl.text.trim(),
                                      'phone': phoneCtrl.text.trim(),
                                      'gender': gender,
                                      'hierarchyLevel': level,
                                      'profilePicture': profileUrl,
                                    });
                                  } else {
                                    await _memberService.createMember({
                                      'username': usernameCtrl.text.trim(),
                                      'password': passwordCtrl.text.trim(),
                                      'email': emailCtrl.text.trim(),
                                      'fullNameEnglish': fullNameCtrl.text.trim(),
                                      'fullNameAmharic':
                                          fullNameAmCtrl.text.trim(),
                                      'phone': phoneCtrl.text.trim(),
                                      'gender': gender,
                                      'hierarchyLevel': level,
                                      'profilePicture': profileUrl,
                                      // Parish-scoped creators add to their own
                                      // congregation so it passes rules + scope.
                                      if ((creator?.parishId ?? '').isNotEmpty)
                                        'atbiyaId': creator!.parishId,
                                      'status': 'active',
                                    });
                                  }
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  _reload();
                                } catch (e) {
                                  setSheet(() => saving = false);
                                  if (ctx.mounted) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                        SnackBar(content: Text('Failed: $e')));
                                  }
                                }
                              },
                        child: Text(saving
                            ? 'Saving…'
                            : (isEditing ? 'Save' : 'Create Member'),
                            style: const TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label,
      {bool required = false,
      bool obscure = false,
      TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        obscureText: obscure,
        keyboardType: keyboardType,
        decoration: InputDecoration(
            labelText: label, border: const OutlineInputBorder()),
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
            : null,
      ),
    );
  }

  Widget _dropdown(String label, String value, List<String> items,
      ValueChanged<String> onChanged) {
    final safeItems = items.isEmpty ? [value] : items;
    final safeValue = safeItems.contains(value) ? value : safeItems.first;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: safeValue,
        isExpanded: true,
        decoration: InputDecoration(
            labelText: label, border: const OutlineInputBorder()),
        items: safeItems
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        onChanged: (v) => onChanged(v ?? safeValue),
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(15)),
            child: FaIcon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.notoSansEthiopic(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
              Text(value, style: GoogleFonts.notoSansEthiopic(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            margin: const EdgeInsets.symmetric(horizontal: 32),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.15),
              ),
            ),
            child: Column(
              children: [
                FaIcon(FontAwesomeIcons.usersSlash,
                    size: 48, color: AppColors.primary.withOpacity(0.2)),
                const SizedBox(height: 16),
                Text(
                  'NO MEMBERS FOUND',
                  style: GoogleFonts.notoSansEthiopic(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    color: AppColors.lightText.withOpacity(0.3),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
