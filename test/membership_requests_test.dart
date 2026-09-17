import 'package:flutter_test/flutter_test.dart';

import 'package:mobile_ahaw/screens/dashboard_items/membership_requests_page.dart';

/// The congregation filter is built from the pending requests rather than the
/// registry, the way the web's `congregationOptions` does — a congregation
/// with nothing waiting is not worth offering as a filter.
void main() {
  List<Map<String, dynamic>> req(String id, String name) => [
        {'atbiyaId': id, 'atbiyaName': name},
      ];

  test('groups by congregation and counts each', () {
    final options = congregationOptions([
      ...req('b', 'St Michael'),
      ...req('a', 'St Mary'),
      ...req('a', 'St Mary'),
    ]);

    expect(options.map((o) => o.name), ['St Mary', 'St Michael']);
    expect(options.firstWhere((o) => o.id == 'a').count, 2);
    expect(options.firstWhere((o) => o.id == 'b').count, 1);
  });

  test('offers only congregations that have something pending', () {
    // Nothing pending anywhere means no filter bar at all.
    expect(congregationOptions(const []), isEmpty);
  });

  test('skips a request with no congregation rather than inventing one', () {
    // atbiyaId is required at sign-up, but a record written by an older build
    // may lack it; it must not become a nameless filter chip.
    final options = congregationOptions([
      {'atbiyaId': '', 'atbiyaName': 'ignored'},
      ...req('a', 'St Mary'),
    ]);
    expect(options, hasLength(1));
    expect(options.single.id, 'a');
  });

  test('falls back to the id when a request carries no congregation name', () {
    final options = congregationOptions([
      {'atbiyaId': 'a'},
    ]);
    expect(options.single.name, 'a');
  });
}
