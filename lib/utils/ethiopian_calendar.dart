/// Ethiopian ⇄ Gregorian date conversion — a port of the web's
/// src/lib/ethiopian-calendar.ts.
///
/// Both directions go through the Julian Day Number, which is what makes the
/// conversion exact rather than an approximation with a fixed offset: the two
/// calendars' new years drift against each other, and the 13th month (ጳጉሜ) is
/// 5 or 6 days depending on the leap cycle.
library;

/// JDN of 1 መስከረም 1 E.C.
const int _ethiopicEpoch = 1723856;

/// Ethiopian month names per language.
///
/// Tigrinya uses the same Ge'ez month names as Amharic. Afaan Oromoo uses the
/// Latin transliterations rather than invented translations, which is what
/// Oromo-language Ethiopian calendars in common use do.
class EthiopianMonth {
  final int id;
  final String am;
  final String en;
  final String ti;
  final String om;
  const EthiopianMonth(this.id, this.am, this.en, this.ti, this.om);

  String nameFor(String lang) => switch (lang) {
        'en' => en,
        'ti' => ti,
        'om' => om,
        _ => am,
      };
}

const List<EthiopianMonth> ethiopianMonths = [
  EthiopianMonth(1, 'መስከረም', 'Meskerem', 'መስከረም', 'Meskeraam'),
  EthiopianMonth(2, 'ጥቅምት', 'Tikimt', 'ጥቅምቲ', 'Tiqimti'),
  EthiopianMonth(3, 'ሕዳር', 'Hidar', 'ሕዳር', 'Hidaar'),
  EthiopianMonth(4, 'ታኅሣሥ', 'Tahsas', 'ታሕሳስ', 'Tahsaas'),
  EthiopianMonth(5, 'ጥር', 'Tir', 'ጥሪ', 'Tiri'),
  EthiopianMonth(6, 'የካቲት', 'Yekatit', 'ለካቲት', 'Yakaatiit'),
  EthiopianMonth(7, 'መጋቢት', 'Megabit', 'መጋቢት', 'Magaabiit'),
  EthiopianMonth(8, 'ሚያዝያ', 'Miyazya', 'ሚያዝያ', 'Miyaaziyaa'),
  EthiopianMonth(9, 'ግንቦት', 'Ginbot', 'ግንቦት', 'Ginboot'),
  EthiopianMonth(10, 'ሰኔ', 'Sene', 'ሰነ', 'Seenee'),
  EthiopianMonth(11, 'ሐምሌ', 'Hamle', 'ሓምለ', 'Hamlee'),
  EthiopianMonth(12, 'ነሐሴ', 'Nehase', 'ነሓሰ', 'Nahaasee'),
  EthiopianMonth(13, 'ጳጉሜ', 'Pagume', 'ጳጉሜ', 'Phaagumee'),
];

/// An Ethiopian month's name in the reader's language.
String ethiopianMonthName(int id, String lang) =>
    ethiopianMonths[id.clamp(1, 13) - 1].nameFor(lang);

/// True when the Ethiopian year is a leap year — ጳጉሜ has 6 days instead of 5.
bool isEthiopianLeapYear(int ethYear) => ethYear % 4 == 3;

/// Days in an Ethiopian month. Every month is 30 days except the 13th.
int ethiopianDaysInMonth(int ethYear, int ethMonth) =>
    ethMonth == 13 ? (isEthiopianLeapYear(ethYear) ? 6 : 5) : 30;

int _gregorianToJdn(int year, int month, int day) {
  final a = (14 - month) ~/ 12;
  final y = year + 4800 - a;
  final m = month + 12 * a - 3;
  return day +
      (153 * m + 2) ~/ 5 +
      365 * y +
      y ~/ 4 -
      y ~/ 100 +
      y ~/ 400 -
      32045;
}

({int year, int month, int day}) _jdnToGregorian(int jdn) {
  final a = jdn + 32044;
  final b = (4 * a + 3) ~/ 146097;
  final c = a - (146097 * b) ~/ 4;
  final d = (4 * c + 3) ~/ 1461;
  final e = c - (1461 * d) ~/ 4;
  final m = (5 * e + 2) ~/ 153;
  return (
    day: e - (153 * m + 2) ~/ 5 + 1,
    month: m + 3 - 12 * (m ~/ 10),
    year: 100 * b + d - 4800 + (m ~/ 10),
  );
}

/// The true inverse of [_jdnToEthiopian].
///
/// NOTE: this deliberately does NOT mirror `ethiopianToJDN` in the web's
/// src/lib/ethiopian-calendar.ts, which computes
/// `EPOCH + 365*(year-1) + floor(year/4) + …`. That expression is not the
/// inverse of the web's own `jdnToEthiopian` and lands exactly one year early —
/// `toGregorianDate(2017, 1, 1)` returns 2023-09-12 where 1 መስከረም 2017 is
/// 2024-09-11. Porting it verbatim would have written every date of birth a
/// year out.
///
/// Derived by inverting `jdnToEthiopian` directly: within each 1461-day
/// (4-year) cycle, `k = year % 4` selects the 365-day block and the leap day
/// falls at the end of the block where `k == 3`, which is the same rule
/// [isEthiopianLeapYear] states.
int _ethiopianToJdn(int year, int month, int day) {
  final n = 30 * (month - 1) + (day - 1);
  final k = year % 4;
  final q = year ~/ 4;
  return _ethiopicEpoch + 1461 * q + 365 * k + n;
}

({int year, int month, int day}) _jdnToEthiopian(int jdn) {
  final r = (jdn - _ethiopicEpoch) % 1461;
  final n = r % 365 + 365 * (r ~/ 1460);
  return (
    year: 4 * ((jdn - _ethiopicEpoch) ~/ 1461) + r ~/ 365 - r ~/ 1460,
    month: n ~/ 30 + 1,
    day: n % 30 + 1,
  );
}

class EthiopianDate {
  final int year;
  final int month;
  final int day;
  const EthiopianDate(this.year, this.month, this.day);

  String monthName([String lang = 'am']) => ethiopianMonthName(month, lang);

  /// e.g. `መስከረም 5, 2017 ዓ.ም.`
  String formatted([String lang = 'am']) =>
      '${monthName(lang)} $day, $year ዓ.ም.';
}

/// Gregorian → Ethiopian. Falls back to today when [date] is null.
EthiopianDate toEthiopianDate([DateTime? date]) {
  final d = date ?? DateTime.now();
  final e = _jdnToEthiopian(_gregorianToJdn(d.year, d.month, d.day));
  return EthiopianDate(e.year, e.month, e.day);
}

/// Ethiopian → Gregorian, at midnight local time.
DateTime toGregorianDate(int ethYear, int ethMonth, int ethDay) {
  final g = _jdnToGregorian(_ethiopianToJdn(ethYear, ethMonth, ethDay));
  return DateTime(g.year, g.month, g.day);
}

/// `YYYY-MM-DD`, the form the `users` document stores `dateOfBirth` in.
String isoFrom(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
