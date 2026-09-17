/// CSV parsing for bulk import, matching BulkImportDialog in the web's
/// src/components/BulkImportDialog.tsx.
///
/// Deliberately the same naive split the web uses — one line per row, one
/// comma per column — rather than a full RFC 4180 parser. Matching it means a
/// file that imports on the web imports here, and a file that breaks on the
/// web breaks here rather than producing a different set of members.
library;

import 'dart:convert';

/// One parsed row, before it becomes a user.
class CsvMemberRow {
  final String fullName;
  final String fullNameAmharic;
  final String phone;
  final String email;
  final String role;

  const CsvMemberRow({
    required this.fullName,
    this.fullNameAmharic = '',
    this.phone = '',
    this.email = '',
    this.role = '',
  });

  /// The synthetic username the web derives: the name with everything but
  /// letters and digits removed, falling back to the digits of the phone.
  String usernameFor() {
    final base = fullName.isNotEmpty
        ? fullName
        : phone.replaceAll(RegExp(r'\D'), '');
    final cleaned =
        base.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return cleaned.isEmpty
        ? ''
        : cleaned.substring(0, cleaned.length > 20 ? 20 : cleaned.length);
  }
}

/// Thrown when the file cannot be a member list.
class CsvFormatException implements Exception {
  const CsvFormatException();
}

/// Column aliases, lower-cased, in the order the web checks them.
const _aliases = <String, List<String>>{
  'fullName': ['name', 'fullname', 'full name'],
  'fullNameAmharic': ['name_amharic', 'amharic', 'name amharic'],
  'phone': ['phone', 'phone_number', 'telephone'],
  'email': ['email'],
  'role': ['role', 'hierarchy', 'level'],
};

/// Parses [text] into rows. Throws [CsvFormatException] when there is no
/// header plus at least one data row.
List<CsvMemberRow> parseMemberCsv(String text) {
  final lines = const LineSplitter()
      .convert(text)
      .where((l) => l.trim().isNotEmpty)
      .toList();
  if (lines.length < 2) throw const CsvFormatException();

  final header =
      lines.first.toLowerCase().split(',').map((h) => h.trim()).toList();

  String pick(List<String> values, String field) {
    for (final alias in _aliases[field]!) {
      final idx = header.indexOf(alias);
      if (idx != -1 && idx < values.length) {
        final v = values[idx].trim();
        if (v.isNotEmpty) return v;
      }
    }
    return '';
  }

  final rows = <CsvMemberRow>[];
  for (var i = 1; i < lines.length; i++) {
    final values = lines[i].split(',').map((v) => v.trim()).toList();
    // The web skips anything with fewer than two columns as an empty row.
    if (values.length < 2) continue;
    rows.add(CsvMemberRow(
      fullName: pick(values, 'fullName'),
      fullNameAmharic: pick(values, 'fullNameAmharic'),
      phone: pick(values, 'phone'),
      email: pick(values, 'email'),
      role: pick(values, 'role'),
    ));
  }
  return rows;
}
