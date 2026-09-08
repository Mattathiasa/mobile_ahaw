import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/localization_service.dart';
import '../../services/permission_service.dart';
import '../../services/cloudinary_service.dart';
import '../../theme/app_colors.dart';

/// Mirrors the web Memriya Documents page: folder/file browsing of the
/// `documents` collection (name, type folder|file, parentId, size, fileType,
/// filePath) with breadcrumb navigation and search.
class DocumentsPage extends StatefulWidget {
  const DocumentsPage({super.key});

  @override
  State<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends State<DocumentsPage> {
  // Breadcrumb trail: list of (id, name); empty = root
  final List<MapEntry<String, String>> _path = [];
  String _search = '';

  String? get _currentParentId => _path.isEmpty ? null : _path.last.key;

  bool _uploading = false;

  Future<void> _createFolder() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Folder'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Folder name'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Create')),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    await FirebaseFirestore.instance.collection('documents').add({
      'name': name,
      'type': 'folder',
      'parentId': _currentParentId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _uploadFile() async {
    try {
      final res = await FilePicker.platform.pickFiles(withData: false);
      final path = res?.files.single.path;
      if (res == null || path == null) return;
      final f = res.files.single;
      setState(() => _uploading = true);
      final url = await CloudinaryService.uploadFile(
        File(path),
        folder: 'mahibere-ahaw/documents',
        resourceType: 'auto',
      );
      await FirebaseFirestore.instance.collection('documents').add({
        'name': f.name,
        'type': 'file',
        'parentId': _currentParentId,
        'size': '${(f.size / 1024).toStringAsFixed(2)} KB',
        'fileType': f.extension ?? '',
        'filePath': url,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _deleteDocument(String id, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete?'),
        content: Text('Delete "$name"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete',
                  style: TextStyle(color: AppColors.sacredRed))),
        ],
      ),
    );
    if (ok == true) {
      await FirebaseFirestore.instance.collection('documents').doc(id).delete();
    }
  }

  void _showAddSheet(bool canUpload) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.create_new_folder_outlined,
                  color: AppColors.primary),
              title: const Text('New Folder'),
              onTap: () {
                Navigator.pop(ctx);
                _createFolder();
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.upload_file, color: AppColors.primary),
              title: const Text('Upload File'),
              onTap: () {
                Navigator.pop(ctx);
                _uploadFile();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final perms = Provider.of<PermissionService>(context);
    final canUpload = perms.isSuperAdmin || perms.can('canUploadDocuments');
    final canDelete = perms.isSuperAdmin || perms.can('canDeleteDocuments');

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      floatingActionButton: canUpload
          ? FloatingActionButton(
              onPressed: _uploading ? null : () => _showAddSheet(canUpload),
              backgroundColor: AppColors.primary,
              child: _uploading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.add, color: Colors.white),
            )
          : null,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(Provider.of<LocalizationService>(context).t('documents'),
            style: GoogleFonts.notoSansEthiopic(
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : AppColors.lightText,
            )),
        leading: IconButton(
          icon: Icon(Icons.arrow_back,
              color: isDark ? Colors.white : AppColors.lightText),
          onPressed: () {
            if (_path.isNotEmpty) {
              setState(() => _path.removeLast());
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: Column(
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: TextField(
              onChanged: (v) => setState(() => _search = v.toLowerCase()),
              style: GoogleFonts.notoSansEthiopic(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search documents...',
                hintStyle: GoogleFonts.notoSansEthiopic(
                    fontSize: 13, color: Colors.grey),
                prefixIcon:
                    const Icon(Icons.search, size: 18, color: Colors.grey),
                filled: true,
                fillColor:
                    isDark ? Colors.white.withOpacity(0.05) : Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide:
                      BorderSide(color: AppColors.primary.withOpacity(0.1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide:
                      BorderSide(color: AppColors.primary.withOpacity(0.1)),
                ),
              ),
            ),
          ),
          // Breadcrumb
          if (_path.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => setState(() => _path.clear()),
                      child: Text('Home',
                          style: GoogleFonts.notoSansEthiopic(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                          )),
                    ),
                    for (var i = 0; i < _path.length; i++) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(Icons.chevron_right,
                            size: 14, color: Colors.grey),
                      ),
                      GestureDetector(
                        onTap: () => setState(
                            () => _path.removeRange(i + 1, _path.length)),
                        child: Text(_path[i].value,
                            style: GoogleFonts.notoSansEthiopic(
                              fontSize: 11,
                              fontWeight: i == _path.length - 1
                                  ? FontWeight.w900
                                  : FontWeight.bold,
                              color: i == _path.length - 1
                                  ? (isDark ? Colors.white : AppColors.lightText)
                                  : AppColors.primary,
                            )),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          // Contents
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('documents')
                  .where('parentId', isEqualTo: _currentParentId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child:
                          CircularProgressIndicator(color: AppColors.primary));
                }
                if (snapshot.hasError) {
                  return _message(Icons.error_outline, 'Could not load documents');
                }

                var items = (snapshot.data?.docs ?? [])
                    .map((d) => {'id': d.id, ...d.data()})
                    .toList();

                if (_search.isNotEmpty) {
                  items = items
                      .where((d) => (d['name'] as String? ?? '')
                          .toLowerCase()
                          .contains(_search))
                      .toList();
                }

                // Folders first, then alphabetical (matches web ordering)
                items.sort((a, b) {
                  final aFolder = a['type'] == 'folder' ? 0 : 1;
                  final bFolder = b['type'] == 'folder' ? 0 : 1;
                  if (aFolder != bFolder) return aFolder - bFolder;
                  return (a['name'] as String? ?? '')
                      .toLowerCase()
                      .compareTo((b['name'] as String? ?? '').toLowerCase());
                });

                if (items.isEmpty) {
                  return _message(FontAwesomeIcons.folderOpen,
                      _search.isNotEmpty ? 'No matches' : 'This folder is empty');
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: items.length,
                  itemBuilder: (context, index) =>
                      _buildItem(items[index], isDark, index, canDelete),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _message(IconData icon, String text) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 56, color: AppColors.primary.withOpacity(0.4)),
          const SizedBox(height: 16),
          Text(text,
              style: GoogleFonts.notoSansEthiopic(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              )),
        ],
      ),
    );
  }

  Widget _buildItem(
      Map<String, dynamic> item, bool isDark, int index, bool canDelete) {
    final isFolder = item['type'] == 'folder';
    final name = item['name'] as String? ?? 'Unnamed';
    final size = item['size'] as String? ?? '';

    return GestureDetector(
      onTap: () {
        if (isFolder) {
          setState(() {
            _path.add(MapEntry(item['id'] as String, name));
            _search = '';
          });
        } else {
          _openFile(item);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.primary.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (isFolder ? AppColors.primary : Colors.amber)
                    .withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: FaIcon(
                isFolder ? FontAwesomeIcons.solidFolder : FontAwesomeIcons.file,
                color: isFolder ? AppColors.primary : Colors.amber.shade700,
                size: 16,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.notoSansEthiopic(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: isDark ? Colors.white : AppColors.lightText,
                      )),
                  if (size.isNotEmpty)
                    Text(size,
                        style: GoogleFonts.notoSansEthiopic(
                            fontSize: 10, color: Colors.grey)),
                ],
              ),
            ),
            Icon(
              isFolder ? Icons.chevron_right : Icons.open_in_new,
              size: 16,
              color: Colors.grey,
            ),
            if (canDelete)
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    size: 18, color: AppColors.sacredRed),
                onPressed: () =>
                    _deleteDocument(item['id'] as String, name),
              ),
          ],
        ),
      ).animate().fadeIn(delay: (index * 50).ms),
    );
  }

  Future<void> _openFile(Map<String, dynamic> item) async {
    final filePath = item['filePath'] as String? ?? '';
    final uri = Uri.tryParse(filePath);
    if (filePath.startsWith('http') && uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No downloadable link for this file',
              style: GoogleFonts.notoSansEthiopic()),
        ),
      );
    }
  }
}
