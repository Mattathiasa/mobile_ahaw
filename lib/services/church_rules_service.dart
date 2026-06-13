import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Reads the Church Rules (Hige Denb) the web admin edits
/// (siteConfig/churchRules). Three categories: Regulations (ደንብ),
/// Directives (መመሪያ), Policies. Mobile is read-only; editing is on the web.
class RuleItem {
  final String title;
  final String content;
  const RuleItem(this.title, this.content);
}

class ChurchRulesService extends ChangeNotifier {
  List<RuleItem> denb = _defaultDenb;
  List<RuleItem> memerya = _defaultMemerya;
  List<RuleItem> policies = _defaultPolicies;
  bool loaded = false;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;

  ChurchRulesService() {
    _sub = FirebaseFirestore.instance
        .collection('siteConfig')
        .doc('churchRules')
        .snapshots()
        .listen((snap) {
      final data = snap.data();
      if (data != null) {
        denb = _parse(data['denb']) ?? _defaultDenb;
        memerya = _parse(data['memerya']) ?? _defaultMemerya;
        policies = _parse(data['policies']) ?? _defaultPolicies;
      }
      loaded = true;
      notifyListeners();
    }, onError: (e) {
      if (kDebugMode) print('[ChurchRules] listen failed: $e');
      loaded = true;
      notifyListeners();
    });
  }

  static List<RuleItem>? _parse(dynamic raw) {
    if (raw is! List) return null;
    return raw
        .whereType<Map>()
        .map((m) => RuleItem(
              (m['title'] ?? '').toString(),
              (m['content'] ?? '').toString(),
            ))
        .toList();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  static const _defaultDenb = [
    RuleItem('Sunday Worship', 'All members are expected to attend Sunday worship services regularly with devotion and humility.'),
    RuleItem('Membership Conduct', 'Members must uphold spiritual and moral purity in personal and public life, honoring the hierarchy and spiritual leadership.'),
    RuleItem('Tithe (Asrat)', 'Faithful and regular contribution of the tithe supports the operations and ministry of the church.'),
  ];
  static const _defaultMemerya = [
    RuleItem('Reporting Directive', 'All Memriya members and higher levels must submit regular reports (weekly, monthly, or yearly) on attendance, finance, and ministry progress.'),
    RuleItem('Communication Protocol', 'Official announcements may only be made by Memriya level and above, following the established chain of command.'),
    RuleItem('Ministry Conduct', 'Ministry workers must complete appropriate training and maintain regular attendance and active participation in assigned areas.'),
  ];
  static const _defaultPolicies = [
    RuleItem('Financial Accountability', 'Elections, appointments, and financial management follow the Central Council guidelines; transparency and divine accountability are the pillars of administration.'),
    RuleItem('Asset Stewardship', 'Church funds, property, and sacred items must be handled with care; misuse is strictly prohibited.'),
  ];
}
