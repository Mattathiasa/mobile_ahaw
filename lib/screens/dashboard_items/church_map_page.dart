import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../services/church_map_service.dart';
import '../../services/hierarchy_service.dart';
import '../../services/auth_service.dart';
import '../../services/permission_service.dart';
import '../../services/role_registry_service.dart';
import '../../services/localization_service.dart';
import '../../widgets/dashboard/dashboard_scaffold.dart';
import '../../theme/app_colors.dart';
import '../../widgets/home/home_common.dart';

/// Church Map: an OpenStreetMap canvas of the pinned congregations over the
/// list of all of them, with their pin status.
///
/// An admin places a pin by choosing a congregation and tapping the map, the
/// way the web's ChurchMap does; the coordinate dialog stays for anyone
/// entering a surveyed position. Pins live in `atbiyaPrivate` — never on the
/// congregation's own document, which anonymous visitors can read.
///
/// Only the congregation layer is drawn. The web also plots the head office,
/// the dioceses (including an estimated position for a diocese with no pin of
/// its own) and the Mahedherat; this screen has only ever managed
/// congregations, and the other three would each need their own query.
///
/// Tiles come from OpenStreetMap over the network, so with no connection the
/// canvas is blank and the list below it is the whole screen.
class ChurchMapPage extends StatefulWidget {
  const ChurchMapPage({super.key});

  @override
  State<ChurchMapPage> createState() => _ChurchMapPageState();
}

class _ChurchMapPageState extends State<ChurchMapPage> {
  LocalizationService get loc =>
      Provider.of<LocalizationService>(context, listen: false);

  final ChurchMapService _mapService = ChurchMapService();
  final HierarchyService _hierarchy = HierarchyService();
  // Cache of loaded coords per atbiya id (null = loaded & unpinned).
  final Map<String, ({double lat, double lng})?> _coords = {};

  final MapController _map = MapController();

  /// The congregation being placed, if any. While this is set, a tap on the
  /// map drops its pin instead of doing nothing.
  Map<String, dynamic>? _placing;

  /// Ids whose coordinates have been fetched, so the map can be drawn once
  /// rather than a marker at a time.
  bool _coordsLoaded = false;

  Future<void> _loadAllCoords(List<Map<String, dynamic>> atbiyas) async {
    final ids = atbiyas.map((a) => a['id'] as String).toList();
    final found = await _mapService.getCoordsFor(ids);
    if (!mounted) return;
    setState(() {
      for (final id in ids) {
        _coords[id] = found[id];
      }
      _coordsLoaded = true;
    });
  }

  bool get _canEdit {
    final perms = Provider.of<PermissionService>(context, listen: false);
    final registry = Provider.of<RoleRegistryService>(context, listen: false);
    final level =
        Provider.of<AuthService>(context, listen: false).userModel?.hierarchyLevel;
    return perms.isSuperAdmin || registry.isAdminRole(level);
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LocalizationService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DashboardScaffold(
      titleKey: 'nav.churchMap',
      moduleKey: 'churchMap',
      constrainWidth: false,
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _hierarchy.getEntitiesByLevel('Atbiya'),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.primary));
          }
          final atbiyas = snapshot.data ?? [];
          if (atbiyas.isEmpty) {
            return _empty(loc.t('admin.noCongregationsYet'));
          }
          if (!_coordsLoaded) {
            WidgetsBinding.instance.addPostFrameCallback(
                (_) => _loadAllCoords(atbiyas));
          }

          final placed = atbiyas
              .where((a) => _coords[a['id'] as String] != null)
              .toList();
          final unplaced = atbiyas
              .where((a) =>
                  _coordsLoaded && _coords[a['id'] as String] == null)
              .toList();

          return Column(children: [
            _mapCanvas(placed, isDark),
            _mapStatus(placed.length, unplaced.length, isDark),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                children: [...atbiyas.map((a) => _tile(a, isDark))],
              ),
            ),
          ]);
        },
      ),
    );
  }

  /// The congregation layer. The web draws head office, dioceses and
  /// Mahedherat alongside it; this screen only ever managed congregations, so
  /// only that layer is here. Colour matches PIN_COLORS.atbiya in the web's
  /// src/lib/mapIcon.ts, and the amber is its `selected`.
  static const _pinAtbiya = Color(0xFF2E5E99);
  static const _pinSelected = Color(0xFFE0A200);

  /// Roughly the middle of Ethiopia, for the first frame when nothing is
  /// placed yet and there is no point to centre on.
  static const _fallbackCentre = LatLng(9.15, 40.49);

  Widget _mapCanvas(List<Map<String, dynamic>> placed, bool isDark) {
    final points = <Marker>[];
    for (final a in placed) {
      final c = _coords[a['id'] as String]!;
      final isTarget = _placing != null && _placing!['id'] == a['id'];
      points.add(Marker(
        point: LatLng(c.lat, c.lng),
        width: 34,
        height: 34,
        child: Tooltip(
          message: (a['name'] ?? '') as String,
          child: Icon(Icons.location_on,
              size: 30, color: isTarget ? _pinSelected : _pinAtbiya),
        ),
      ));
    }

    final first = placed.isEmpty
        ? _fallbackCentre
        : LatLng(_coords[placed.first['id'] as String]!.lat,
            _coords[placed.first['id'] as String]!.lng);

    return SizedBox(
      height: 260,
      child: Stack(children: [
        FlutterMap(
          mapController: _map,
          options: MapOptions(
            initialCenter: first,
            // The web uses 6 when it has points to fit and 11 when it does
            // not; without a fitted bounds here, 6 shows the country.
            initialZoom: placed.isEmpty ? 5.5 : 6,
            onTap: (_, latLng) => _onMapTap(latLng),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              // OpenStreetMap asks that clients identify themselves.
              userAgentPackageName: 'org.et.mahibereahaw.app',
            ),
            MarkerLayer(markers: points),
          ],
        ),
        // OSM's licence requires visible attribution.
        Positioned(
          right: 0,
          bottom: 0,
          child: GestureDetector(
            onTap: () => openExternal('https://www.openstreetmap.org/copyright',
                context: context),
            child: Container(
              color: Colors.white70,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: const Text('© OpenStreetMap',
                  style: TextStyle(fontSize: 9, color: Colors.black87)),
            ),
          ),
        ),
        if (_placing != null)
          Positioned(
            left: 12,
            right: 12,
            top: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _pinSelected,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                const Icon(Icons.touch_app, size: 16, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_placing!['name'] ?? ''} — ${loc.t('admin.tapToPlace')}',
                    style: GoogleFonts.notoSansEthiopic(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: Colors.white),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _placing = null),
                  child: const Icon(Icons.close, size: 16, color: Colors.white),
                ),
              ]),
            ),
          ),
      ]),
    );
  }

  Widget _mapStatus(int placed, int unplaced, bool isDark) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
        child: Row(children: [
          Text(loc.t('admin.pinnedCount', {'n': '$placed'}),
              style: GoogleFonts.notoSansEthiopic(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: _pinAtbiya)),
          const SizedBox(width: 12),
          if (unplaced > 0)
            Text(loc.t('admin.unpinnedCount', {'n': '$unplaced'}),
                style: GoogleFonts.notoSansEthiopic(
                    fontSize: 11, color: Colors.grey)),
          const Spacer(),
          if (_canEdit && _placing == null && unplaced > 0)
            Text(loc.t('admin.needsPinHint'),
                textAlign: TextAlign.end,
                style: GoogleFonts.notoSansEthiopic(
                    fontSize: 9, color: Colors.grey)),
        ]),
      );

  Future<void> _onMapTap(LatLng at) async {
    final target = _placing;
    if (target == null || !_canEdit) return;
    final id = target['id'] as String;
    try {
      await _mapService.setCoords(id, at.latitude, at.longitude);
      if (!mounted) return;
      setState(() {
        _coords[id] = (lat: at.latitude, lng: at.longitude);
        _placing = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.t('admin.pinSaved'))));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(loc.t('errors.generic'))));
      }
    }
  }

  Widget _tile(Map<String, dynamic> atbiya, bool isDark) {
    final id = atbiya['id'] as String;
    final name = atbiya['name'] ?? atbiya['nameAmharic'] ?? loc.t('admin.congregationBadge');

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
            color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.08)),
          ),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: (pinned ? const Color(0xFF10B981) : Colors.grey)
                      .withValues(alpha: 0.12),
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
                    : loc.t('admin.noPin'),
                style: GoogleFonts.notoSansEthiopic(
                    fontSize: 10, color: Colors.grey)),
            trailing: _canEdit
                ? Row(mainAxisSize: MainAxisSize.min, children: [
                    // Placing by tapping the map is the quick path; the
                    // coordinate dialog stays for anyone typing a surveyed
                    // position in.
                    IconButton(
                      tooltip: loc.t('admin.tapToPlace'),
                      icon: Icon(Icons.touch_app_outlined,
                          color: _placing != null && _placing!['id'] == id
                              ? _pinSelected
                              : AppColors.primary),
                      onPressed: () {
                        setState(() => _placing = atbiya);
                        final c = _coords[id];
                        if (c != null) {
                          _map.move(LatLng(c.lat, c.lng), 13);
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_location_alt_outlined,
                          color: AppColors.primary),
                      onPressed: () => _editPin(id, name.toString(), coords),
                    ),
                  ])
                : (pinned
                    ? const Icon(Icons.open_in_new,
                        size: 18, color: AppColors.primary)
                    : null),
            onTap: pinned
                ? () => _map.move(LatLng(coords.lat, coords.lng), 14)
                : null,
            onLongPress: pinned
                ? () => _openInMaps(context, coords.lat, coords.lng)
                : null,
          ),
        );
      },
    );
  }

  Future<void> _openInMaps(
      BuildContext context, double lat, double lng) async {
    await openExternal(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
      context: context,
    );
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
        title: Text('${loc.t('admin.parishLocation')}: $name'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: latCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true, signed: true),
            decoration: InputDecoration(
                labelText: loc.t('admin.latitude'),
                border: const OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: lngCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true, signed: true),
            decoration: InputDecoration(
                labelText: loc.t('admin.longitude'),
                border: const OutlineInputBorder()),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(loc.t('common.cancel'))),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(loc.t('common.save'))),
        ],
      ),
    );
    if (ok != true) return;
    final lat = double.tryParse(latCtrl.text.trim());
    final lng = double.tryParse(lngCtrl.text.trim());
    if (lat == null || lng == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(loc.t('admin.invalidCoords'))));
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
            .showSnackBar(SnackBar(content: Text(loc.t('errors.generic'))));
      }
    }
  }

  Widget _empty(String msg) => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          FaIcon(FontAwesomeIcons.mapLocationDot,
              size: 56, color: AppColors.primary.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(msg,
              style: GoogleFonts.notoSansEthiopic(
                  fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
        ]),
      );
}
