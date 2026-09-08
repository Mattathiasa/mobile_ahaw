import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/church_map_service.dart';
import '../../services/hierarchy_service.dart';
import '../../services/auth_service.dart';
import '../../services/permission_service.dart';
import '../../services/role_registry_service.dart';
import '../../theme/app_colors.dart';

/// Lightweight Church Map: lists congregations with their pin status, opens a
/// pin in the phone's maps app, and lets admins set/edit coordinates. Pins are
/// stored in atbiyaPrivate (same as the web); no embedded map / API key needed.
class ChurchMapPage extends StatefulWidget {
  const ChurchMapPage({super.key});

  @override
  State<ChurchMapPage> createState() => _ChurchMapPageState();
}

class _ChurchMapPageState extends State<ChurchMapPage> {
  final ChurchMapService _mapService = ChurchMapService();
  final HierarchyService _hierarchy = HierarchyService();
  // Cache of loaded coords per atbiya id (null = loaded & unpinned).
  final Map<String, ({double lat, double lng})?> _coords = {};

  bool get _canEdit {
    final perms = Provider.of<PermissionService>(context, listen: false);
    final registry = Provider.of<RoleRegistryService>(context, listen: false);
    final level =
        Provider.of<AuthService>(context, listen: false).userModel?.hierarchyLevel;
    return perms.isSuperAdmin || registry.isAdminRole(level);
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
        title: Text('Church Map',
            style: GoogleFonts.notoSansEthiopic(
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : AppColors.lightText)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back,
              color: isDark ? Colors.white : AppColors.lightText),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _hierarchy.getEntitiesByLevel('Atbiya'),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.primary));
          }
          final atbiyas = snapshot.data ?? [];
          if (atbiyas.isEmpty) {
            return _empty('No congregations to map yet');
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12, left: 4),
                child: Text(
                    'Tap a pinned congregation to open it in Maps.'
                    '${_canEdit ? ' Use the pin icon to set its location.' : ''}',
                    style: GoogleFonts.notoSansEthiopic(
                        fontSize: 11, color: Colors.grey)),
              ),
              ...atbiyas.map((a) => _tile(a, isDark)),
            ],
          );
        },
      ),
    );
  }

  Widget _tile(Map<String, dynamic> atbiya, bool isDark) {
    final id = atbiya['id'] as String;
    final name = atbiya['name'] ?? atbiya['nameAmharic'] ?? 'Congregation';

    return FutureBuilder<({double lat, double lng})?>(
      future: _coords.containsKey(id)
          ? Future.value(_coords[id])
          : _mapService.getCoords(id).then((v) {
              _coords[id] = v;
              return v;
            }),
      builder: (context, snap) {
        final coords = snap.data;
        final pinned = coords != null;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withOpacity(0.08)),
          ),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: (pinned ? const Color(0xFF10B981) : Colors.grey)
                      .withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12)),
              child: FaIcon(
                  pinned
                      ? FontAwesomeIcons.locationDot
                      : FontAwesomeIcons.locationPinLock,
                  size: 15,
                  color: pinned ? const Color(0xFF10B981) : Colors.grey),
            ),
            title: Text(name,
                style: GoogleFonts.notoSansEthiopic(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    color: isDark ? Colors.white : AppColors.lightText)),
            subtitle: Text(
                pinned
                    ? '${coords.lat.toStringAsFixed(5)}, ${coords.lng.toStringAsFixed(5)}'
                    : 'Not pinned',
                style: GoogleFonts.notoSansEthiopic(
                    fontSize: 10, color: Colors.grey)),
            trailing: _canEdit
                ? IconButton(
                    icon: const Icon(Icons.edit_location_alt_outlined,
                        color: AppColors.primary),
                    onPressed: () => _editPin(id, name.toString(), coords),
                  )
                : (pinned
                    ? const Icon(Icons.open_in_new,
                        size: 18, color: AppColors.primary)
                    : null),
            onTap: pinned ? () => _openInMaps(coords.lat, coords.lng) : null,
          ),
        );
      },
    );
  }

  Future<void> _openInMaps(double lat, double lng) async {
    final uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _editPin(
      String id, String name, ({double lat, double lng})? current) async {
    final latCtrl =
        TextEditingController(text: current?.lat.toString() ?? '');
    final lngCtrl =
        TextEditingController(text: current?.lng.toString() ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Pin $name'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: latCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true, signed: true),
            decoration: const InputDecoration(
                labelText: 'Latitude', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: lngCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true, signed: true),
            decoration: const InputDecoration(
                labelText: 'Longitude', border: OutlineInputBorder()),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save')),
        ],
      ),
    );
    if (ok != true) return;
    final lat = double.tryParse(latCtrl.text.trim());
    final lng = double.tryParse(lngCtrl.text.trim());
    if (lat == null || lng == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Enter valid coordinates.')));
      }
      return;
    }
    try {
      await _mapService.setCoords(id, lat, lng);
      _coords[id] = (lat: lat, lng: lng);
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  Widget _empty(String msg) => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          FaIcon(FontAwesomeIcons.mapLocationDot,
              size: 56, color: AppColors.primary.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(msg,
              style: GoogleFonts.notoSansEthiopic(
                  fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
        ]),
      );
}
