DateTime parseApiTimestamp(String value) {
  final normalized = value.trim();
  final parsed = DateTime.parse(normalized);
  final hasTimeZone = RegExp(
    r'(?:Z|[+-]\d{2}:?\d{2})$',
    caseSensitive: false,
  ).hasMatch(normalized);
  if (hasTimeZone) return parsed;

  return DateTime.utc(
    parsed.year,
    parsed.month,
    parsed.day,
    parsed.hour,
    parsed.minute,
    parsed.second,
    parsed.millisecond,
    parsed.microsecond,
  );
}

DateTime? tryParseApiTimestamp(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  return DateTime.tryParse(value.trim()) == null
      ? null
      : parseApiTimestamp(value);
}
