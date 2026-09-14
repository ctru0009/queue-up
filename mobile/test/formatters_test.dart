import 'package:flutter_test/flutter_test.dart';
import 'package:queue_up/formatters.dart';

void main() {
  group('formatDateTime', () {
    test('renders the venue wall time of the featured start', () {
      // 2026-09-18T19:00:00+10:00 is 09:00 UTC. Built from UTC so the
      // expectation cannot drift with the host timezone.
      expect(formatDateTime(DateTime.utc(2026, 9, 18, 9)), 'Fri 18 Sep • 7:00 PM');
      expect(
        formatDateTime(DateTime.parse('2026-09-18T19:00:00+10:00')),
        'Fri 18 Sep • 7:00 PM',
      );
    });

    test('renders the other seed start times in venue wall time', () {
      expect(
        formatDateTime(DateTime.parse('2026-09-18T19:45:00+10:00')),
        'Fri 18 Sep • 7:45 PM',
      );
      expect(
        formatDateTime(DateTime.parse('2026-09-19T13:00:00+10:00')),
        'Sat 19 Sep • 1:00 PM',
      );
      expect(
        formatDateTime(DateTime.parse('2026-09-19T18:30:00+10:00')),
        'Sat 19 Sep • 6:30 PM',
      );
    });

    test('renders the same venue time for the same instant expressed in UTC', () {
      final DateTime venueLocal = DateTime.parse('2026-09-18T19:00:00+10:00');

      expect(venueLocal.isUtc, isTrue);
      expect(formatDateTime(venueLocal), formatDateTime(DateTime.utc(2026, 9, 18, 9)));
    });

    test('renders a local-time DateTime as its venue instant', () {
      // The same instant expressed in local form must render identically: the
      // venue wall clock is derived from the instant, not from the device zone.
      final DateTime instant = DateTime.utc(2026, 9, 18, 9);

      expect(formatDateTime(instant.toLocal()), formatDateTime(instant));
      expect(formatDateTime(instant), 'Fri 18 Sep • 7:00 PM');
    });
  });

  group('formatStations', () {
    test('renders nothing for an empty assignment', () {
      expect(formatStations(<String>[]), '');
    });

    test('renders a single station', () {
      expect(formatStations(<String>['B11']), 'B11');
    });

    test('collapses the contiguous seed assignment with an en dash', () {
      final String formatted = formatStations(<String>['B11', 'B12', 'B13', 'B14', 'B15']);

      expect(formatted, 'B11\u2013B15');
      expect(formatted.contains('\u2013'), isTrue);
      expect(formatted.contains('-'), isFalse);
    });

    test('collapses runs and keeps separated stations as a list', () {
      expect(formatStations(<String>['B11', 'B12', 'B14']), 'B11\u2013B12, B14');
      expect(formatStations(<String>['B11', 'B13']), 'B11, B13');
      expect(formatStations(<String>['B11', 'B12', 'A1']), 'B11\u2013B12, A1');
      expect(formatStations(<String>['B11', 'B12', 'B14', 'B15']), 'B11\u2013B12, B14\u2013B15');
    });

    test('keeps unparseable station ids verbatim', () {
      expect(formatStations(<String>['VIP', 'B11', 'B12']), 'VIP, B11\u2013B12');
    });
  });
}
