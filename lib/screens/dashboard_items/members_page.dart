import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../../services/member_service.dart';
import '../../services/auth_service.dart';
import '../../services/permission_service.dart';
import '../../services/role_registry_service.dart';
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
    // Scope the directory read to what firestore.rules allows for this user
    // (head office / diocese see everyone; a parish sees only its own members).
    final auth = Provider.of<AuthService>(context, listen: false);
    final perms = Provider.of<PermissionService>(context, listen: false);
    final registry =
        Provider.of<RoleRegistryService>(context, listen: false);
    final user = auth.userModel;
    final scope = registry.memberScopeFor(
      roleKey: user?.hierarchyLevel,
      isSuperAdmin: perms.isSuperAdmin,
      atbiyaId: user?.parishId ?? '',
    );
    _membersFuture = _memberService.getMembersInScope(
      wholeDirectory: scope.wholeDirectory,
      atbiyaId: scope.atbiyaId,
    );
  }

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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Add Member logic
        },
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ).animate().scale(delay: 500.ms),
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
              Center(
                child: CircleAvatar(
                  radius: 60,
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  child: Text(
                    (member['fullNameEnglish'] ?? 'U')[0],
                    style: GoogleFonts.notoSansEthiopic(fontSize: 40, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                ),
              ),
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
            ],
          ),
        ),
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
