import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../services/localization_service.dart';
import '../../services/permission_service.dart';
import '../../services/module_config_service.dart';
import '../../widgets/image_upload_field.dart';
import '../../theme/app_colors.dart';

/// Mirrors the web Teaching page: lists the `teachings` collection
/// (title, speaker, serviceType, shortDescription, dateDelivered) with a
/// full-content detail sheet.
class TeachingsPage extends StatelessWidget {
  const TeachingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(Provider.of<LocalizationService>(context).t('teachings'),
            style: GoogleFonts.notoSansEthiopic(
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : AppColors.lightText,
            )),
        leading: IconButton(
          icon: Icon(Icons.arrow_back,
              color: isDark ? Colors.white : AppColors.lightText),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('teachings')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.primary));
          }
          if (snapshot.hasError) {
            return _emptyState(
                isDark, Icons.error_outline, 'Could not load teachings');
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return _emptyState(isDark, FontAwesomeIcons.bookOpenReader,
                'No teachings published yet');
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data();
              return _TeachingCard(
                  id: docs[index].id, data: data, isDark: isDark, index: index);
            },
          );
        },
      ),
      floatingActionButton:
          Provider.of<PermissionService>(context).can('canCreateTeaching')
              ? FloatingActionButton(
                  onPressed: () => showTeachingForm(context),
                  backgroundColor: AppColors.primary,
                  child: const Icon(Icons.add, color: Colors.white),
                )
              : null,
    );
  }

  Widget _emptyState(bool isDark, IconData icon, String message) {
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
}

class _TeachingCard extends StatelessWidget {
  final String id;
  final Map<String, dynamic> data;
  final bool isDark;
  final int index;

  const _TeachingCard(
      {required this.id,
      required this.data,
      required this.isDark,
      required this.index});

  @override
  Widget build(BuildContext context) {
    final title = (data['title'] as String?) ?? 'Untitled';
    final speaker = (data['speaker'] as String?) ?? '';
    final serviceType = (data['serviceType'] as String?) ?? '';
    final shortDescription = (data['shortDescription'] as String?) ?? '';
    final dateDelivered = (data['dateDelivered'] as String?) ?? '';

    return GestureDetector(
      onTap: () => _showDetail(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.primary.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const FaIcon(FontAwesomeIcons.bookOpenReader,
                      color: AppColors.primary, size: 16),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: GoogleFonts.notoSansEthiopic(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            color: isDark ? Colors.white : AppColors.lightText,
                          )),
                      if (speaker.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(speaker,
                            style: GoogleFonts.notoSansEthiopic(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            )),
                      ],
                    ],
                  ),
                ),
                if (serviceType.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(serviceType.toUpperCase(),
                        style: GoogleFonts.notoSansEthiopic(
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                          letterSpacing: 0.4,
                        )),
                  ),
              ],
            ),
            if (shortDescription.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(shortDescription,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.notoSansEthiopic(
                    fontSize: 12,
                    height: 1.5,
                    color: isDark ? Colors.white60 : Colors.grey.shade600,
                  )),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                if (dateDelivered.isNotEmpty) ...[
                  const Icon(Icons.calendar_today_outlined,
                      size: 11, color: Colors.grey),
                  const SizedBox(width: 5),
                  Text(dateDelivered,
                      style: GoogleFonts.notoSansEthiopic(
                          fontSize: 10, color: Colors.grey)),
                ],
                const Spacer(),
                Text('READ MORE',
                    style: GoogleFonts.notoSansEthiopic(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                      letterSpacing: 0.6,
                    )),
              ],
            ),
          ],
        ),
      ).animate().fadeIn(delay: (index * 80).ms).slideY(begin: 0.05),
    );
  }

  void _showDetail(BuildContext context) {
    final title = (data['title'] as String?) ?? 'Untitled';
    final speaker = (data['speaker'] as String?) ?? '';
    final fullContent = (data['fullContent'] as String?) ??
        (data['shortDescription'] as String?) ??
        '';
    final dateDelivered = (data['dateDelivered'] as String?) ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor:
          isDark ? AppColors.darkSurface : AppColors.lightBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(title,
                  style: GoogleFonts.notoSansEthiopic(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : AppColors.lightText,
                  )),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (speaker.isNotEmpty) ...[
                    const Icon(Icons.person_outline,
                        size: 14, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(speaker,
                        style: GoogleFonts.notoSansEthiopic(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        )),
                    const SizedBox(width: 16),
                  ],
                  if (dateDelivered.isNotEmpty) ...[
                    const Icon(Icons.calendar_today_outlined,
                        size: 12, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(dateDelivered,
                        style: GoogleFonts.notoSansEthiopic(
                            fontSize: 11, color: Colors.grey)),
                  ],
                ],
              ),
              const SizedBox(height: 20),
              Text(fullContent,
                  style: GoogleFonts.notoSansEthiopic(
                    fontSize: 14,
                    height: 1.8,
                    color: isDark ? Colors.white70 : AppColors.lightText,
                  )),
              if (Provider.of<PermissionService>(context, listen: false)
                  .can('canCreateTeaching')) ...[
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          showTeachingForm(context, id: id, existing: data);
                        },
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('Edit'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.sacredRed),
                        onPressed: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Delete teaching?'),
                              content: Text('Delete "$title"?'),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Cancel')),
                                TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Delete',
                                        style:
                                            TextStyle(color: AppColors.sacredRed))),
                              ],
                            ),
                          );
                          if (ok == true) {
                            await FirebaseFirestore.instance
                                .collection('teachings')
                                .doc(id)
                                .delete();
                            if (context.mounted) Navigator.pop(context);
                          }
                        },
                        icon: const Icon(Icons.delete_outline, size: 16),
                        label: const Text('Delete'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Create/edit a teaching. Mirrors the web CreateTeachingDialog: title,
/// speaker, service type (from Module Config), short/full content, date,
/// featured image (Cloudinary) and published/draft status.
void showTeachingForm(BuildContext context,
    {String? id, Map<String, dynamic>? existing}) {
  final isEditing = id != null;
  final moduleConfig = Provider.of<ModuleConfigService>(context, listen: false);
  final serviceTypes = moduleConfig.options('teachings', 'serviceTypes');

  final titleCtrl = TextEditingController(text: existing?['title']);
  final speakerCtrl = TextEditingController(text: existing?['speaker']);
  final shortCtrl = TextEditingController(text: existing?['shortDescription']);
  final fullCtrl = TextEditingController(text: existing?['fullContent']);
  final dateCtrl = TextEditingController(
      text: existing?['dateDelivered'] ??
          DateTime.now().toIso8601String().split('T').first);
  String serviceType = existing?['serviceType']?.toString() ??
      (serviceTypes.isNotEmpty ? serviceTypes.first : 'Other');
  String status = existing?['status']?.toString() ?? 'Published';
  String featuredImage = existing?['featuredImage']?.toString() ?? '';
  final formKey = GlobalKey<FormState>();
  bool saving = false;

  Widget field(TextEditingController c, String label,
          {bool required = false, int maxLines = 1}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: c,
          maxLines: maxLines,
          decoration: InputDecoration(
              labelText: label, border: const OutlineInputBorder()),
          validator: required
              ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
              : null,
        ),
      );

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
                  Text(isEditing ? 'Edit Teaching' : 'New Teaching',
                      style: GoogleFonts.notoSansEthiopic(
                          fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 16),
                  Center(
                    child: ImageUploadField(
                      initialUrl: featuredImage,
                      folder: 'teachings',
                      circle: false,
                      size: 120,
                      label: 'Featured image',
                      onUploaded: (url) => featuredImage = url,
                    ),
                  ),
                  const SizedBox(height: 16),
                  field(titleCtrl, 'Title', required: true),
                  field(speakerCtrl, 'Speaker'),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: DropdownButtonFormField<String>(
                      value: serviceTypes.contains(serviceType)
                          ? serviceType
                          : (serviceTypes.isNotEmpty
                              ? serviceTypes.first
                              : serviceType),
                      isExpanded: true,
                      decoration: const InputDecoration(
                          labelText: 'Service Type',
                          border: OutlineInputBorder()),
                      items: (serviceTypes.isEmpty ? [serviceType] : serviceTypes)
                          .map((e) =>
                              DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (v) =>
                          setSheet(() => serviceType = v ?? serviceType),
                    ),
                  ),
                  field(shortCtrl, 'Short Description', maxLines: 2),
                  field(fullCtrl, 'Full Content', maxLines: 5),
                  field(dateCtrl, 'Date Delivered (YYYY-MM-DD)'),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: DropdownButtonFormField<String>(
                      value: status,
                      isExpanded: true,
                      decoration: const InputDecoration(
                          labelText: 'Status', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(
                            value: 'Published', child: Text('Published')),
                        DropdownMenuItem(value: 'Draft', child: Text('Draft')),
                      ],
                      onChanged: (v) => setSheet(() => status = v ?? 'Published'),
                    ),
                  ),
                  const SizedBox(height: 8),
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
                              final payload = {
                                'title': titleCtrl.text.trim(),
                                'speaker': speakerCtrl.text.trim(),
                                'serviceType': serviceType,
                                'shortDescription': shortCtrl.text.trim(),
                                'fullContent': fullCtrl.text.trim(),
                                'dateDelivered': dateCtrl.text.trim(),
                                'featuredImage': featuredImage,
                                'status': status,
                                'updatedAt': FieldValue.serverTimestamp(),
                              };
                              try {
                                final col = FirebaseFirestore.instance
                                    .collection('teachings');
                                if (isEditing) {
                                  await col.doc(id).update(payload);
                                } else {
                                  await col.add({
                                    ...payload,
                                    'createdAt': FieldValue.serverTimestamp(),
                                  });
                                }
                                if (ctx.mounted) Navigator.pop(ctx);
                              } catch (e) {
                                setSheet(() => saving = false);
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(content: Text('Failed: $e')));
                                }
                              }
                            },
                      child: Text(
                          saving ? 'Saving…' : (isEditing ? 'Save' : 'Publish'),
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
