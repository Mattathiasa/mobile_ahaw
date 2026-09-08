import 'package:cloud_firestore/cloud_firestore.dart';

/// Reads/writes congregation map pins. Coordinates live in
/// `atbiyaPrivate/{atbiyaId}` as `lat`/`lng` numbers, keyed by the hierarchy
/// doc id — the same place the web Church Map stores them.
class ChurchMapService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<({double lat, double lng})?> getCoords(String atbiyaId) async {
    try {
      final snap = await _db.collection('atbiyaPrivate').doc(atbiyaId).get();
      final data = snap.data();
      final lat = (data?['lat'] as num?)?.toDouble();
      final lng = (data?['lng'] as num?)?.toDouble();
      if (lat != null && lng != null) return (lat: lat, lng: lng);
    } catch (_) {
      // Permission-denied for a non-privileged caller → treat as unpinned.
    }
    return null;
  }

  Future<void> setCoords(String atbiyaId, double lat, double lng) async {
    await _db.collection('atbiyaPrivate').doc(atbiyaId).set({
      'lat': lat,
      'lng': lng,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
