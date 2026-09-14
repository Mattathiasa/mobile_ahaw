import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_ahaw/utils/ethiopian_calendar.dart';
import 'package:mobile_ahaw/utils/phone.dart';

/// Both of these are ports of web helpers that silently corrupt data when they
/// are subtly wrong: a bad conversion writes the wrong date of birth onto a
/// member record, and a bad normalizer stores a number nobody can call.
void main() {
  group('normalizeEthiopianPhone', () {
    test('accepts the ways an Ethiopian number is actually typed', () {
      const expected = '+251911223344';
      expect(normalizeEthiopianPhone('0911223344'), expected);
      expect(normalizeEthiopianPhone('911223344'), expected);
      expect(normalizeEthiopianPhone('+251 911 22 33 44'), expected);
      expect(normalizeEthiopianPhone('00251-911-223344'), expected);
      expect(normalizeEthiopianPhone('251911223344'), expected);
    });

    test('keeps a foreign number rather than rejecting it', () {
      // Turning away a diaspora member's number would lock them out of an app
      // whose whole purpose is to reach them.
      expect(normalizeEthiopianPhone('+1 202 555 0143'), '+12025550143');
    });

    test('rejects what cannot be a phone number', () {
      expect(normalizeEthiopianPhone(''), isNull);
      expect(normalizeEthiopianPhone('   '), isNull);
      expect(normalizeEthiopianPhone('12345'), isNull);
      expect(normalizeEthiopianPhone(null), isNull);
      expect(isValidPhone('0911223344'), isTrue);
      expect(isValidPhone('abc'), isFalse);
    });
  });

  group('Ethiopian calendar', () {
    test('converts the new year anchors both ways', () {
      // 1 መስከረም 2017 = 11 September 2024.
      final ny2017 = toEthiopianDate(DateTime(2024, 9, 11));
      expect([ny2017.year, ny2017.month, ny2017.day], [2017, 1, 1]);
      expect(toGregorianDate(2017, 1, 1), DateTime(2024, 9, 11));

      // 2015 is a leap year, so ጳጉሜ ran to 6 days and 2016 opened a day later.
      final ny2016 = toEthiopianDate(DateTime(2023, 9, 12));
      expect([ny2016.year, ny2016.month, ny2016.day], [2016, 1, 1]);
      expect(toGregorianDate(2016, 1, 1), DateTime(2023, 9, 12));
    });

    test('round-trips every day across a leap boundary', () {
      var d = DateTime(2023, 1, 1);
      final end = DateTime(2026, 1, 1);
      while (d.isBefore(end)) {
        final e = toEthiopianDate(d);
        expect(toGregorianDate(e.year, e.month, e.day), d,
            reason: 'round-trip failed for $d');
        d = d.add(const Duration(days: 1));
      }
    });

    test('knows the length of the 13th month', () {
      expect(isEthiopianLeapYear(2015), isTrue);
      expect(isEthiopianLeapYear(2016), isFalse);
      expect(ethiopianDaysInMonth(2015, 13), 6);
      expect(ethiopianDaysInMonth(2016, 13), 5);
      expect(ethiopianDaysInMonth(2016, 1), 30);
    });

    test('names months in each supported language', () {
      expect(ethiopianMonthName(1, 'am'), 'መስከረም');
      expect(ethiopianMonthName(1, 'en'), 'Meskerem');
      expect(ethiopianMonthName(2, 'ti'), 'ጥቅምቲ');
      expect(ethiopianMonthName(13, 'om'), 'Phaagumee');
      // Out-of-range ids clamp rather than throwing.
      expect(ethiopianMonthName(0, 'am'), 'መስከረም');
      expect(ethiopianMonthName(99, 'am'), 'ጳጉሜ');
    });

    test('formats an ISO date the way the users document stores it', () {
      expect(isoFrom(DateTime(1995, 3, 7)), '1995-03-07');
    });
  });
}
