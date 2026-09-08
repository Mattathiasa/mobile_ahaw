import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../services/news_service.dart';
import '../../services/auth_service.dart';
import '../../services/permission_service.dart';
import '../../services/role_registry_service.dart';
import '../../services/localization_service.dart';
import '../../services/cloudinary_service.dart';
import '../../widgets/image_upload_field.dart';
import '../../theme/app_colors.dart';

/// News / blog: a published feed for everyone, plus a manage view (drafts +
/// create/edit/publish/delete) for canManageNews roles.
class NewsPage extends StatefulWidget {
  const NewsPage({super.key});

  @override
  State<NewsPage> createState() => _NewsPageState();
}

class _NewsPageState extends State<NewsPage> {
  final NewsService _service = NewsService();
  bool _manageView = false;
  Future<List<Map<String, dynamic>>>? _manageFuture;

  String get _lang =>
      Provider.of<LocalizationService>(context, listen: false).language;

  bool get _canManage {
    final perms = Provider.of<PermissionService>(context, listen: false);
    return perms.isSuperAdmin || perms.can('canManageNews');
  }

  void _loadManage() {
    final auth = Provider.of<AuthService>(context, listen: false);
    final perms = Provider.of<PermissionService>(context, listen: false);
    final registry = Provider.of<RoleRegistryService>(context, listen: false);
    final user = auth.userModel;
    final scope = registry.memberScopeFor(
      roleKey: user?.hierarchyLevel,
      isSuperAdmin: perms.isSuperAdmin,
      atbiyaId: user?.parishId ?? '',
    );
    setState(() {
      _manageFuture = _service.listForAuthor(
          isHeadOffice: scope.wholeDirectory, atbiyaId: scope.atbiyaId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('News',
            style: GoogleFonts.notoSansEthiopic(
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : AppColors.lightText)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back,
              color: isDark ? Colors.white : AppColors.lightText),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_canManage)
            TextButton(
              onPressed: () {
                setState(() => _manageView = !_manageView);
                if (_manageView && _manageFuture == null) _loadManage();
              },
              child: Text(_manageView ? 'Feed' : 'Manage',
                  style: GoogleFonts.notoSansEthiopic(
                      fontWeight: FontWeight.w900, color: AppColors.primary)),
            ),
        ],
      ),
      floatingActionButton: (_canManage && _manageView)
          ? FloatingActionButton(
              onPressed: () => _openEditor(context),
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      body: _manageView ? _buildManage(isDark) : _buildFeed(isDark),
    );
  }

  // ── Public feed ───────────────────────────────────────────────────────────
  Widget _buildFeed(bool isDark) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _service.watchPublished(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.primary));
        }
        final posts = snapshot.data ?? [];
        if (posts.isEmpty) return _empty('No news yet');
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: posts.length,
          itemBuilder: (context, i) => _postCard(posts[i], isDark, i, false),
        );
      },
    );
  }

  // ── Manage view ─────────────────────────────────────────────────────────────
  Widget _buildManage(bool isDark) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _manageFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.primary));
        }
        final posts = snapshot.data ?? [];
        if (posts.isEmpty) return _empty('No posts yet — create one');
        return RefreshIndicator(
          onRefresh: () async => _loadManage(),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: posts.length,
            itemBuilder: (context, i) => _postCard(posts[i], isDark, i, true),
          ),
        );
      },
    );
  }

  Widget _postCard(
      Map<String, dynamic> p, bool isDark, int index, bool manage) {
    final title = NewsService.pickText(p['title'], _lang);
    final excerpt = NewsService.pickText(p['excerpt'], _lang);
    final cover = (p['coverImageUrl'] as String?) ?? '';
    final status = p['status'] as String? ?? 'draft';

    return GestureDetector(
      onTap: () => _showDetail(p),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary.withOpacity(0.08)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (cover.isNotEmpty)
            Image.network(CloudinaryService.optimized(cover, width: 800),
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink()),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(title.isEmpty ? 'Untitled' : title,
                          style: GoogleFonts.notoSansEthiopic(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              color: isDark ? Colors.white : AppColors.lightText)),
                    ),
                    if (manage)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                            color: (status == 'published'
                                    ? const Color(0xFF10B981)
                                    : AppColors.divineGold)
                                .withOpacity(0.14),
                            borderRadius: BorderRadius.circular(8)),
                        child: Text(status.toUpperCase(),
                            style: GoogleFonts.notoSansEthiopic(
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                                color: status == 'published'
                                    ? const Color(0xFF10B981)
                                    : AppColors.divineGold)),
                      ),
                  ]),
                  if (excerpt.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(excerpt,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.notoSansEthiopic(
                            fontSize: 12,
                            color: isDark ? Colors.white60 : Colors.grey.shade600)),
                  ],
                  const SizedBox(height: 8),
                  Row(children: [
                    Icon(Icons.person_outline,
                        size: 12, color: Colors.grey.withOpacity(0.7)),
                    const SizedBox(width: 4),
                    Text(p['authorName'] ?? '',
                        style: GoogleFonts.notoSansEthiopic(
                            fontSize: 10, color: Colors.grey)),
                    const Spacer(),
                    if (manage)
                      _manageMenu(p, status),
                  ]),
                ]),
          ),
        ]),
      ),
    ).animate().fadeIn(delay: (index * 40).ms);
  }

  Widget _manageMenu(Map<String, dynamic> p, String status) {
    return SizedBox(
      height: 26,
      child: PopupMenuButton<String>(
        padding: EdgeInsets.zero,
        icon: const Icon(Icons.more_vert, size: 18),
        onSelected: (v) async {
          if (v == 'edit') {
            _openEditor(context, existing: p);
          } else if (v == 'publish') {
            await _service.setStatus(p['id'] as String, 'published');
            _loadManage();
          } else if (v == 'unpublish') {
            await _service.setStatus(p['id'] as String, 'draft');
            _loadManage();
          } else if (v == 'delete') {
            await _service.remove(p['id'] as String);
            _loadManage();
          }
        },
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'edit', child: Text('Edit')),
          if (status != 'published')
            const PopupMenuItem(value: 'publish', child: Text('Publish'))
          else
            const PopupMenuItem(value: 'unpublish', child: Text('Unpublish')),
          const PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
      ),
    );
  }

  void _showDetail(Map<String, dynamic> p) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = NewsService.pickText(p['title'], _lang);
    final body = NewsService.pickText(p['body'], _lang);
    final cover = (p['coverImageUrl'] as String?) ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor:
          isDark ? AppColors.darkSurface : AppColors.lightBackground,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          children: [
            Center(
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 16),
            if (cover.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                    CloudinaryService.optimized(cover, width: 1000),
                    errorBuilder: (_, __, ___) => const SizedBox.shrink()),
              ),
            const SizedBox(height: 16),
            Text(title,
                style: GoogleFonts.notoSansEthiopic(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : AppColors.lightText)),
            const SizedBox(height: 12),
            Text(body,
                style: GoogleFonts.notoSansEthiopic(
                    fontSize: 14,
                    height: 1.8,
                    color: isDark ? Colors.white70 : AppColors.lightText)),
          ],
        ),
      ),
    );
  }

  // ── Create / edit editor ─────────────────────────────────────────────────────
  void _openEditor(BuildContext context, {Map<String, dynamic>? existing}) {
    final isEditing = existing != null;
    final user = Provider.of<AuthService>(context, listen: false).userModel;

    final titleEn = TextEditingController(
        text: (existing?['title'] as Map?)?['en']?.toString());
    final titleAm = TextEditingController(
        text: (existing?['title'] as Map?)?['am']?.toString());
    final excerptEn = TextEditingController(
        text: (existing?['excerpt'] as Map?)?['en']?.toString());
    final bodyEn = TextEditingController(
        text: (existing?['body'] as Map?)?['en']?.toString());
    final bodyAm = TextEditingController(
        text: (existing?['body'] as Map?)?['am']?.toString());
    String cover = existing?['coverImageUrl']?.toString() ?? '';
    String scope = existing?['scope']?.toString() ?? 'global';
    String status = existing?['status']?.toString() ?? 'draft';
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
                borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
            padding: const EdgeInsets.all(20),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isEditing ? 'Edit Post' : 'New Post',
                        style: GoogleFonts.notoSansEthiopic(
                            fontSize: 18, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 16),
                    Center(
                      child: ImageUploadField(
                        initialUrl: cover,
                        folder: 'news',
                        circle: false,
                        size: 120,
                        label: 'Cover image',
                        onUploaded: (url) => cover = url,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _field(titleEn, 'Title (English)', required: true),
                    _field(titleAm, 'Title (Amharic)'),
                    _field(excerptEn, 'Excerpt', maxLines: 2),
                    _field(bodyEn, 'Body (English)', maxLines: 5),
                    _field(bodyAm, 'Body (Amharic)', maxLines: 5),
                    _dropdown('Scope', scope, const ['global', 'atbiya'],
                        (v) => setSheet(() => scope = v)),
                    _dropdown('Status', status, const ['draft', 'published'],
                        (v) => setSheet(() => status = v)),
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
                                final data = <String, dynamic>{
                                  'title': {
                                    'en': titleEn.text.trim(),
                                    'am': titleAm.text.trim(),
                                  },
                                  'excerpt': {'en': excerptEn.text.trim()},
                                  'body': {
                                    'en': bodyEn.text.trim(),
                                    'am': bodyAm.text.trim(),
                                  },
                                  'coverImageUrl': cover,
                                  'scope': scope,
                                  'status': status,
                                  'atbiyaId':
                                      scope == 'atbiya' ? (user?.parishId ?? '') : null,
                                  'atbiyaName': scope == 'atbiya'
                                      ? {'en': user?.atbiyaName ?? ''}
                                      : null,
                                  'authorId': user?.id ?? '',
                                  'authorName': user?.fullNameEnglish ??
                                      user?.fullName ??
                                      user?.username ??
                                      '',
                                  'authorRole': user?.hierarchyLevel ?? '',
                                  'tags': <String>[],
                                };
                                try {
                                  if (isEditing) {
                                    await _service.update(
                                        existing['id'] as String, data);
                                  } else {
                                    await _service.create(data);
                                  }
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  _loadManage();
                                } catch (e) {
                                  setSheet(() => saving = false);
                                  if (ctx.mounted) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                        SnackBar(content: Text('Failed: $e')));
                                  }
                                }
                              },
                        child: Text(saving ? 'Saving…' : 'Save',
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
      {bool required = false, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        maxLines: maxLines,
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: items.contains(value) ? value : items.first,
        isExpanded: true,
        decoration: InputDecoration(
            labelText: label, border: const OutlineInputBorder()),
        items: items
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        onChanged: (v) => onChanged(v ?? value),
      ),
    );
  }

  Widget _empty(String msg) => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          FaIcon(FontAwesomeIcons.newspaper,
              size: 56, color: AppColors.primary.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(msg,
              style: GoogleFonts.notoSansEthiopic(
                  fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
        ]),
      );
}
