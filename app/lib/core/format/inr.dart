// Indian-Rupee formatting helpers used across the UI.
//
// The `en_IN` locale gives the lakh-crore grouping (e.g. 1,23,456) that
// users expect instead of the default thousands-grouping (1,234,567).
import 'package:intl/intl.dart';

// Rupees without paise — default for totals, KPIs, list rows.
final _inr = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 0,
);

// Rupees with paise — used on bill details and PDF line items.
final _inr2 = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 2,
);

/// Formats [value] as Indian Rupees.
///
/// Returns an em-dash for `null` so empty cells render neutrally.
/// Pass `paise: true` to include two decimals.
String fmtINR(num? value, {bool paise = false}) {
  if (value == null) return '—';
  return (paise ? _inr2 : _inr).format(value);
}

/// Extracts 1-2 uppercase initials from a person's name.
///
/// Used for avatar chips in the top bar / customer rows.
///   "Manoj Patel"   -> "MP"
///   "Ramesh"        -> "R"
///   ""              -> "?"
String initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
  return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
}
