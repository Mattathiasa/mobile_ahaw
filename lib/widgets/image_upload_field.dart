import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/cloudinary_service.dart';
import '../theme/app_colors.dart';

/// A reusable image field: shows the current image, lets the user pick one from
/// the gallery, uploads it to Cloudinary, and reports the secure URL via
/// [onUploaded]. Used for avatars, news covers, teaching images, etc.
class ImageUploadField extends StatefulWidget {
  final String? initialUrl;
  final ValueChanged<String> onUploaded;
  final String folder;
  final double size;
  final bool circle;
  final String label;

  const ImageUploadField({
    super.key,
    this.initialUrl,
    required this.onUploaded,
    this.folder = 'mahibere-ahaw',
    this.size = 96,
    this.circle = true,
    this.label = 'Upload image',
  });

  @override
  State<ImageUploadField> createState() => _ImageUploadFieldState();
}

class _ImageUploadFieldState extends State<ImageUploadField> {
  final ImagePicker _picker = ImagePicker();
  String? _url;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _url = widget.initialUrl;
  }

  Future<void> _pick() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (picked == null) return;
      setState(() => _uploading = true);
      final url = await CloudinaryService.uploadFile(
        File(picked.path),
        folder: widget.folder,
      );
      if (!mounted) return;
      setState(() {
        _url = url;
        _uploading = false;
      });
      widget.onUploaded(url);
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.circle
        ? BorderRadius.circular(widget.size)
        : BorderRadius.circular(16);
    final hasImage = _url != null && _url!.isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _uploading ? null : _pick,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: radius,
              border: Border.all(color: AppColors.primary.withOpacity(0.2)),
            ),
            clipBehavior: Clip.antiAlias,
            child: _uploading
                ? const Center(
                    child: CircularProgressIndicator(strokeWidth: 2))
                : hasImage
                    ? Image.network(
                        CloudinaryService.optimized(_url!, width: 400),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                            Icons.broken_image,
                            color: AppColors.primary),
                      )
                    : const Icon(Icons.add_a_photo, color: AppColors.primary),
          ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: _uploading ? null : _pick,
          icon: const Icon(Icons.upload, size: 16),
          label: Text(_uploading ? 'Uploading…' : widget.label),
        ),
      ],
    );
  }
}
