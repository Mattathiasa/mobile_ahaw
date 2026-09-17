import 'package:flutter_test/flutter_test.dart';

import 'package:mobile_ahaw/services/announcement_broadcast.dart';

/// Role targeting happens on the client, by resolving the audience to people
/// before any notification is written — so this filter IS the targeting. If it
/// is wrong, an announcement meant for Memriya reaches the whole church, and
/// nothing downstream would catch it.
void main() {
  Map<String, dynamic> member(
    String id, {
    String? level,
    String? status,
  }) =>
      {
        'id': id,
        if (level != null) 'hierarchyLevel': level,
        if (status != null) 'status': status,
      };

  final people = [
    member('a', level: 'Memriya'),
    member('b', level: 'Atbiya'),
    member('c', level: 'Memriya', status: 'pending'),
    member('d', level: 'Zone', status: 'suspended'),
    member('e'),
  ];

  group('filterRecipients', () {
    test('everyone means every active member', () {
      final got = filterRecipients(people, const AnnouncementAudience.everyone());
      // c is pending and d suspended; e has no level but is active.
      expect(got.map((m) => m['id']), ['a', 'b', 'e']);
    });

    test('roles means only those levels', () {
      final got = filterRecipients(
          people, const AnnouncementAudience.roles(['Memriya']));
      // a matches; c matches the role but is not active.
      expect(got.map((m) => m['id']), ['a']);
    });

    test('a member with no level never matches a role audience', () {
      // Otherwise an unassigned account would receive every targeted
      // announcement.
      final got = filterRecipients(
          [member('e')], const AnnouncementAudience.roles(['Memriya']));
      expect(got, isEmpty);
    });

    test('an absent status counts as active', () {
      // Accounts predating sign-up carry no status; excluding them would
      // silently drop the oldest members of the church.
      final got = filterRecipients(
          [member('x', level: 'Atbiya')], const AnnouncementAudience.everyone());
      expect(got, hasLength(1));
    });

    test('the author is not told about their own announcement', () {
      final got = filterRecipients(
          people, const AnnouncementAudience.everyone(),
          authorId: 'a');
      expect(got.map((m) => m['id']), ['b', 'e']);
    });

    test('an empty authorId excludes nobody', () {
      final got = filterRecipients(
          people, const AnnouncementAudience.everyone(),
          authorId: '');
      expect(got.map((m) => m['id']), ['a', 'b', 'e']);
    });
  });

  group('audience shape', () {
    test('serializes the way the web stores it', () {
      // Both clients read this field, so the shapes have to agree.
      expect(const AnnouncementAudience.everyone().toMap(),
          {'kind': 'everyone'});
      expect(const AnnouncementAudience.parish('atb-1').toMap(),
          {'kind': 'parish', 'atbiyaId': 'atb-1'});
      expect(const AnnouncementAudience.roles(['Memriya', 'Zone']).toMap(),
          {'kind': 'roles', 'roles': ['Memriya', 'Zone']});
    });
  });

  group('chunk', () {
    test('never exceeds the Firestore batch limit', () {
      final items = List.generate(1000, (i) => i);
      final groups = chunk(items);
      expect(groups.every((g) => g.length <= kNotificationBatchLimit), isTrue);
      expect(groups.expand((g) => g).toList(), items);
      // 450 is the web's number; matching it keeps a send that succeeds on one
      // client succeeding on the other.
      expect(kNotificationBatchLimit, 450);
    });

    test('handles the exact-boundary and empty cases', () {
      expect(chunk(List.generate(450, (i) => i)), hasLength(1));
      expect(chunk(List.generate(451, (i) => i)), hasLength(2));
      expect(chunk(<int>[]), isEmpty);
    });
  });
}
