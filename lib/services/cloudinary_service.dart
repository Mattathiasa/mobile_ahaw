import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

class CloudinaryConfig {
  final String cloudName;
  final String uploadPreset;
  const CloudinaryConfig({required this.cloudName, required this.uploadPreset});
}

/// Cloudinary unsigned uploads, mirroring the web's src/services/cloudinary.ts
/// and src/services/integrations.ts. Firebase Storage is deny-by-default in this
/// project (see storage.rules), so images route to Cloudinary instead.
///
/// Cloud name + unsigned upload preset are admin-managed in
/// `siteConfig/integrations` (fields `cloudinaryCloudName` /
/// `cloudinaryUploadPreset`), with the same shared-project defaults as web so
/// uploads work even before an admin edits the doc.
class CloudinaryService {
  static const String _defaultCloudName = 'dqxcewc2t';
  static const String _defaultUploadPreset = 'mahibere-ahaw';

  static CloudinaryConfig? _cached;

  static Future<CloudinaryConfig> getConfig() async {
    if (_cached != null) return _cached!;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('siteConfig')
          .doc('integrations')
          .get();
      final data = snap.data();
      final name = (data?['cloudinaryCloudName'] as String?)?.trim();
      final preset = (data?['cloudinaryUploadPreset'] as String?)?.trim();
      _cached = CloudinaryConfig(
        cloudName: (name != null && name.isNotEmpty) ? name : _defaultCloudName,
        uploadPreset:
            (preset != null && preset.isNotEmpty) ? preset : _defaultUploadPreset,
      );
    } catch (_) {
      _cached = const CloudinaryConfig(
        cloudName: _defaultCloudName,
        uploadPreset: _defaultUploadPreset,
      );
    }
    return _cached!;
  }

  /// Uploads a local file (unsigned) and returns the delivered secure URL.
  /// [resourceType] is 'image' for photos or 'auto'/'raw' for documents.
  static Future<String> uploadFile(
    File file, {
    String folder = 'mahibere-ahaw',
    String resourceType = 'image',
  }) async {
    final config = await getConfig();
    final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/${config.cloudName}/$resourceType/upload');
    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = config.uploadPreset
      ..fields['folder'] = folder
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw 'Cloudinary upload failed (${res.statusCode}): ${res.body}';
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return json['secure_url'] as String;
  }

  /// Optimised, responsive delivery (auto format + quality). Mirrors
  /// `optimized()` in cloudinary.ts.
  static String optimized(String url, {int width = 1200}) {
    if (!url.contains('/upload/')) return url;
    return url.replaceFirst('/upload/', '/upload/w_$width,f_auto,q_auto,c_limit/');
  }
}
