/// Phone numbers — a port of the web's src/lib/phone.ts.
///
/// Phone is the church's real contact channel: many members have no email at
/// all, which is why sign-up insists on a number but not on an address. So the
/// validation stays deliberately permissive — an Ethiopian number typed any of
/// the usual ways is normalized to E.164, and anything else with enough digits
/// is accepted as a foreign number rather than rejected. Turning away a
/// diaspora member's number would lock them out of an app whose whole purpose
/// is to reach them.
library;

const String _etCountryCode = '251';

/// The shortest run of digits that could plausibly be a phone number. Ethiopian
/// subscriber numbers are 9 digits after the trunk 0, so anything shorter is a
/// typo rather than an unusual format.
const int _minDigits = 9;

/// Returns the number in E.164 form (`+251911223344`), or null when it does
/// not look like a phone number at all.
///
/// Accepts `0911223344`, `911223344`, `+251 911 22 33 44`, `00251-911-223344`
/// and foreign numbers such as `+1 202 555 0143`.
String? normalizeEthiopianPhone(String? raw) {
  final trimmed = (raw ?? '').trim();
  if (trimmed.isEmpty) return null;

  final international = RegExp(r'^(\+|00)').hasMatch(trimmed);
  var bare = trimmed.replaceAll(RegExp(r'\D'), '');
  if (bare.startsWith('00')) bare = bare.substring(2);
  if (bare.length < _minDigits) return null;

  // Already carries the Ethiopian country code, with or without the plus.
  if (bare.startsWith(_etCountryCode)) return '+$bare';

  if (!international) {
    // Local form with the trunk prefix: 0911223344 → +251911223344
    if (bare.startsWith('0')) return '+$_etCountryCode${bare.substring(1)}';
    // Bare subscriber number: 911223344 → +251911223344
    if (bare.length == _minDigits) return '+$_etCountryCode$bare';
  }

  // Somebody's foreign number. Keep it, in E.164 shape.
  return '+$bare';
}

/// Would [normalizeEthiopianPhone] accept this?
bool isValidPhone(String? raw) => normalizeEthiopianPhone(raw) != null;
