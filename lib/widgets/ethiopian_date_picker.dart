import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../services/localization_service.dart';
import '../theme/app_colors.dart';
import '../utils/ethiopian_calendar.dart';

/// A date field that reads in the Ethiopian calendar with a Gregorian escape
/// hatch — the mobile counterpart of the web's EthiopianDatePicker.
///
/// Members give their date of birth in ዓ.ም.; the stored value is always the
/// Gregorian ISO string `YYYY-MM-DD`, which is what `users.dateOfBirth` holds
/// and what every other reader of that field expects.
class EthiopianDatePicker extends StatelessWidget {
  /// Gregorian ISO `YYYY-MM-DD`, or empty when unset.
  final String value;
  final ValueChanged<String> onChanged;
  final String label;

  const EthiopianDatePicker({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final loc = Provider.of<LocalizationService>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final parsed = DateTime.tryParse(value);

    final display = parsed == null
        ? ''
        : '${toEthiopianDate(parsed).formatted(loc.language)}'
            '  ·  ${isoFrom(parsed)}';

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _open(context, parsed, loc),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: AppColors.primary.withValues(alpha: 0.05),
          suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide:
                BorderSide(color: AppColors.primary.withValues(alpha: 0.12)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide:
                BorderSide(color: AppColors.primary.withValues(alpha: 0.12)),
          ),
        ),
        child: Text(
          display.isEmpty ? '—' : display,
          style: GoogleFonts.notoSansEthiopic(
            fontSize: 14,
            color: display.isEmpty
                ? (isDark ? Colors.white38 : Colors.black38)
                : (isDark ? Colors.white : AppColors.lightText),
          ),
        ),
      ),
    );
  }

  Future<void> _open(
      BuildContext context, DateTime? current, LocalizationService loc) async {
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _PickerSheet(initial: current, language: loc.language),
    );
    if (picked != null) onChanged(isoFrom(picked));
  }
}

class _PickerSheet extends StatefulWidget {
  final DateTime? initial;
  final String language;
  const _PickerSheet({required this.initial, required this.language});

  @override
  State<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends State<_PickerSheet> {
  late EthiopianDate _eth =
      toEthiopianDate(widget.initial ?? DateTime(DateTime.now().year - 25));

  int get _year => _eth.year;
  int get _month => _eth.month;
  int get _day => _eth.day;

  /// Years a member could plausibly have been born in, newest first.
  List<int> get _years {
    final thisYear = toEthiopianDate(DateTime.now()).year;
    return [for (var y = thisYear; y >= thisYear - 110; y--) y];
  }

  void _set({int? year, int? month, int? day}) {
    final y = year ?? _year;
    final m = month ?? _month;
    // Changing year or month can strand the day past the end of the month —
    // ጳጉሜ is 5 or 6 days, so this matters more here than in a Gregorian picker.
    final maxDay = ethiopianDaysInMonth(y, m);
    final d = (day ?? _day).clamp(1, maxDay);
    setState(() => _eth = EthiopianDate(y, m, d));
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.language;
    final gregorian = toGregorianDate(_year, _month, _day);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _Dropdown<int>(
                    label: 'ዓ.ም.',
                    value: _year,
                    items: _years,
                    labelOf: (y) => '$y',
                    onChanged: (y) => _set(year: y),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 4,
                  child: _Dropdown<int>(
                    label: ethiopianMonthName(1, lang),
                    value: _month,
                    items: const [1,2,3,4,5,6,7,8,9,10,11,12,13],
                    labelOf: (m) => ethiopianMonthName(m, lang),
                    onChanged: (m) => _set(month: m),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: _Dropdown<int>(
                    label: '#',
                    value: _day,
                    items: [
                      for (var d = 1;
                          d <= ethiopianDaysInMonth(_year, _month);
                          d++)
                        d
                    ],
                    labelOf: (d) => '$d',
                    onChanged: (d) => _set(day: d),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // The Gregorian equivalent, shown live. This is the value that gets
            // stored, so the member can see exactly what they are agreeing to.
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.swap_horiz,
                      size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${_eth.formatted(lang)}   =   ${isoFrom(gregorian)}',
                      style: GoogleFonts.notoSansEthiopic(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // The Gregorian escape hatch, for anyone who knows their date that
            // way instead.
            TextButton.icon(
              onPressed: () async {
                final g = await showDatePicker(
                  context: context,
                  initialDate: gregorian,
                  firstDate: DateTime(DateTime.now().year - 110),
                  lastDate: DateTime.now(),
                );
                if (g != null && context.mounted) Navigator.pop(context, g);
              },
              icon: const Icon(Icons.event, size: 16),
              label: Text(
                'Gregorian',
                style: GoogleFonts.notoSansEthiopic(
                    fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, gregorian),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                  'OK',
                  style: GoogleFonts.notoSansEthiopic(
                      fontSize: 15, fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dropdown<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<T> items;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;

  const _Dropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.labelOf,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: items.contains(value) ? value : items.first,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
      items: items
          .map((i) => DropdownMenuItem<T>(
                value: i,
                child: Text(labelOf(i),
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.notoSansEthiopic(fontSize: 14)),
              ))
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}
