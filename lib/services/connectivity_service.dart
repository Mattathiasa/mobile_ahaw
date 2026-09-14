import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Whether the device currently has a network path.
///
/// Firestore keeps working offline from its disk cache, so the app does not
/// *stop* when this goes false — but the reader deserves to know why nothing
/// is refreshing, and a few actions genuinely cannot proceed (see
/// [transactionsUnavailable]).
///
/// This reports the presence of a network interface, not reachability: a
/// captive portal or a dead uplink still reads as online. That is the honest
/// limit of `connectivity_plus`, and it is why the offline banner is worded as
/// "you appear to be offline" rather than asserted as fact.
class ConnectivityService extends ChangeNotifier {
  bool _online = true;
  StreamSubscription<List<ConnectivityResult>>? _sub;

  bool get isOnline => _online;
  bool get isOffline => !_online;

  /// Approve/reject run inside Firestore transactions, which require a server
  /// round-trip — unlike a plain write, they cannot be queued and replayed.
  /// Callers use this to refuse up front instead of reporting a success that
  /// was only ever served from cache.
  bool get transactionsUnavailable => !_online;

  ConnectivityService() {
    _init();
  }

  Future<void> _init() async {
    try {
      _apply(await Connectivity().checkConnectivity());
    } catch (e) {
      if (kDebugMode) print('[Connectivity] initial check failed: $e');
    }
    _sub = Connectivity().onConnectivityChanged.listen(
      _apply,
      onError: (e) {
        if (kDebugMode) print('[Connectivity] stream failed: $e');
      },
    );
  }

  void _apply(List<ConnectivityResult> results) {
    // `none` is the only result that means no path at all; an empty list is
    // reported on some platforms and is treated the same way.
    final next = results.isNotEmpty &&
        results.any((r) => r != ConnectivityResult.none);
    if (next == _online) return;
    _online = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
