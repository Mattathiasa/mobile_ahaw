import 'package:flutter_test/flutter_test.dart';

import 'package:mobile_ahaw/services/csv_import.dart';

/// The parser deliberately mirrors BulkImportDialog in the web, down to its
/// limitations, so the same file produces the same members in both clients.
void main() {
  group('parseMemberCsv', () {
    test('reads the documented columns', () {
      final rows = parseMemberCsv(
        'name,name_amharic,phone,email,role\n'
        'Abebe Kebede,አበበ ከበደ,+251911223344,abebe@example.org,Atbiya\n',
      );
      expect(rows, hasLength(1));
      expect(rows.single.fullName, 'Abebe Kebede');
      expect(rows.single.fullNameAmharic, 'አበበ ከበደ');
      expect(rows.single.phone, '+251911223344');
      expect(rows.single.email, 'abebe@example.org');
      expect(rows.single.role, 'Atbiya');
    });

    test('accepts the header aliases and any column order', () {
      final rows = parseMemberCsv(
        'ROLE,Telephone,Full Name\n'
        'Zone,0911223344,Kebede Abebe\n',
      );
      expect(rows.single.fullName, 'Kebede Abebe');
      expect(rows.single.phone, '0911223344');
      expect(rows.single.role, 'Zone');
    });

    test('skips blank and one-column rows the way the web does', () {
      final rows = parseMemberCsv(
        'name,phone\n'
        'Abebe,0911\n'
        '\n'
        'JustOneColumn\n'
        'Kebede,0922\n',
      );
      expect(rows.map((r) => r.fullName), ['Abebe', 'Kebede']);
    });

    test('refuses a file with no data rows', () {
      expect(() => parseMemberCsv('name,phone\n'),
          throwsA(isA<CsvFormatException>()));
      expect(() => parseMemberCsv(''), throwsA(isA<CsvFormatException>()));
    });

    test('derives the username the web derives', () {
      // Lower-cased, everything but letters and digits stripped, capped at 20.
      expect(
        const CsvMemberRow(fullName: 'Abebe Kebede!').usernameFor(),
        'abebekebede',
      );
      expect(
        const CsvMemberRow(fullName: 'Aaaaaaaaaabbbbbbbbbbcccccccccc')
            .usernameFor(),
        hasLength(20),
      );
      // No usable name falls back to the digits of the phone.
      expect(
        const CsvMemberRow(fullName: '', phone: '+251 911 22 33 44')
            .usernameFor(),
        '251911223344',
      );
      // An Amharic-only name leaves nothing a username can be built from; the
      // caller has to supply one rather than write an empty username.
      expect(const CsvMemberRow(fullName: 'አበበ').usernameFor(), '');
    });
  });
}
