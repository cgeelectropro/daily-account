import 'package:flutter_test/flutter_test.dart';
import 'package:daily_account/services/duration_parser.dart';

void main() {
  group('parseDurationMinutes', () {
    test('empty string returns 0', () {
      expect(parseDurationMinutes(''), 0);
    });

    test('checkmark returns 0', () {
      expect(parseDurationMinutes('✓'), 0);
    });

    test('"Xh Ym" format', () {
      expect(parseDurationMinutes('1h 30m'), 90);
    });

    test('"XhYm" format with no spaces', () {
      expect(parseDurationMinutes('1h15m'), 75);
    });

    test('"Xh" only', () {
      expect(parseDurationMinutes('2h'), 120);
    });

    test('"Xm" only', () {
      expect(parseDurationMinutes('45m'), 45);
    });

    test('"X minutes" spelled out', () {
      expect(parseDurationMinutes('30 minutes'), 30);
    });

    test('"Xs" seconds-only rounds up to nearest minute', () {
      expect(parseDurationMinutes('90s'), 2); // 90s = 1.5min, ceil to 2
      expect(parseDurationMinutes('30s'), 1); // 30s = 0.5min, ceil to 1
    });

    test('bare number assumed minutes', () {
      expect(parseDurationMinutes('45'), 45);
    });

    test('unparseable string returns 0', () {
      expect(parseDurationMinutes('garbage'), 0);
    });
  });
}
