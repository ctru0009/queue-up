import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

/// The seed events are authored in venue-local time (Australia/Melbourne,
/// UTC+10) while `DateTime.parse` normalises offsets to UTC. Display therefore
/// shifts the instant back onto a fixed UTC+10 wall clock so every device shows
/// the venue's time rather than its own.
const Duration _venueUtcOffset = Duration(hours: 10);

/// Display convention: `Fri 18 Sep • 7:00 PM`.
final DateFormat _dateTimeFormat = _createDateTimeFormat();

/// `intl` ships `en_US` fallback symbols only, so the `en` lookup table has to
/// be installed before the formatter is built. The local symbol source installs
/// it synchronously; the returned future is intentionally discarded so date
/// formatting never depends on app startup order.
DateFormat _createDateTimeFormat() {
  initializeDateFormatting('en');
  return DateFormat('EEE d MMM • h:mm a', 'en');
}

/// En dash used when collapsing contiguous station IDs.
const String _enDash = '\u2013';

/// Formats [value] as the venue-local date and time of the event.
String formatDateTime(DateTime value) =>
    _dateTimeFormat.format(value.toUtc().add(_venueUtcOffset));

/// Formats a station assignment, collapsing contiguous runs.
///
/// `[]` renders empty, `['B11']` renders `B11`, `['B11', 'B12', 'B13']` renders
/// `B11–B13`, and non-contiguous IDs render as a comma-separated list.
String formatStations(List<String> stations) {
  if (stations.isEmpty) {
    return '';
  }

  final List<String> parts = <String>[];
  int index = 0;
  while (index < stations.length) {
    final ({String prefix, int number})? start = _parseStation(stations[index]);
    if (start == null) {
      parts.add(stations[index]);
      index++;
      continue;
    }

    int end = index;
    ({String prefix, int number}) last = start;
    while (end + 1 < stations.length) {
      final ({String prefix, int number})? next = _parseStation(stations[end + 1]);
      if (next == null || next.prefix != last.prefix || next.number != last.number + 1) {
        break;
      }
      end++;
      last = next;
    }

    parts.add(end == index ? stations[index] : '${stations[index]}$_enDash${stations[end]}');
    index = end + 1;
  }
  return parts.join(', ');
}

final RegExp _stationPattern = RegExp(r'^([A-Za-z]+)(\d+)$');

({String prefix, int number})? _parseStation(String station) {
  final RegExpMatch? match = _stationPattern.firstMatch(station);
  if (match == null) {
    return null;
  }
  final int? number = int.tryParse(match.group(2)!);
  if (number == null) {
    return null;
  }
  return (prefix: match.group(1)!, number: number);
}
