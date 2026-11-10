import 'package:flutter_test/flutter_test.dart';
import 'package:triagedesk/utils/api_timestamp.dart';

void main() {
  test('timezone-naive API timestamps are interpreted as UTC', () {
    final timestamp = parseApiTimestamp('2025-03-08T14:25:30');

    expect(timestamp.isUtc, isTrue);
    expect(timestamp, DateTime.utc(2025, 3, 8, 14, 25, 30));
  });

  test('timezone-aware API timestamps preserve their instant', () {
    final timestamp = parseApiTimestamp('2025-03-08T16:25:30+02:00');

    expect(timestamp, DateTime.utc(2025, 3, 8, 14, 25, 30));
  });

  test('invalid and empty optional timestamps return null', () {
    expect(tryParseApiTimestamp(null), isNull);
    expect(tryParseApiTimestamp('  '), isNull);
    expect(tryParseApiTimestamp('not-a-timestamp'), isNull);
  });
}
