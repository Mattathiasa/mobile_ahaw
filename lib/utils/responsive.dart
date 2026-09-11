import 'package:flutter/material.dart';

/// Shared breakpoints + helpers for responsive layout across phones, tablets
/// and web/desktop windows. Mirrors the web admin's Tailwind-ish structure:
///   compact   = < 600  (phones)
///   medium    = 600–1023 (small tablets / narrow web windows)
///   expanded  = >= 1024 (tablets landscape, web, desktop)
class Responsive {
  Responsive._();

  static const double compactMax = 600;
  static const double mediumMax = 1024;

  static bool isCompact(double width) => width < compactMax;
  static bool isMedium(double width) =>
      width >= compactMax && width < mediumMax;
  static bool isExpanded(double width) => width >= mediumMax;

  static bool isCompactOf(BuildContext context) =>
      isCompact(MediaQuery.sizeOf(context).width);
  static bool isMediumOf(BuildContext context) =>
      isMedium(MediaQuery.sizeOf(context).width);
  static bool isExpandedOf(BuildContext context) =>
      isExpanded(MediaQuery.sizeOf(context).width);

  /// Max content width on wide screens so layouts don't stretch absurdly.
  static double contentMaxWidthOf(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return isExpanded(w) ? 1200 : double.infinity;
  }

  /// Horizontal page padding that scales with screen size.
  static EdgeInsets pagePaddingOf(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (isExpanded(w)) return const EdgeInsets.symmetric(horizontal: 48);
    if (isMedium(w)) return const EdgeInsets.symmetric(horizontal: 32);
    return const EdgeInsets.symmetric(horizontal: 20);
  }
}
