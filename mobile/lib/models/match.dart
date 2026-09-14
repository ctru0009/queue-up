import 'parsing.dart';

/// Server-confirmed lifecycle state of a match.
enum MatchStatus {
  scheduled('scheduled', 'Scheduled'),
  ready('ready', 'Ready'),
  inProgress('in_progress', 'In Progress'),
  complete('complete', 'Complete');

  const MatchStatus(this.wireValue, this.label);

  /// Value used by the API payloads.
  final String wireValue;

  /// Human-readable display label.
  final String label;

  /// Maps a wire value, throwing [FormatException] for an unknown status.
  static MatchStatus fromWire(String value) {
    for (final MatchStatus status in MatchStatus.values) {
      if (status.wireValue == value) {
        return status;
      }
    }
    throw FormatException('Unknown match status "$value".');
  }
}

/// A scheduled match for a squad at an event.
class Match {
  const Match({
    required this.id,
    required this.eventId,
    required this.squadId,
    required this.round,
    required this.opponent,
    required this.scheduledAt,
    required this.format,
    required this.status,
    required this.stations,
    required this.readyCount,
    required this.teamSize,
  });

  /// Parses a match payload, throwing [FormatException] when it is malformed.
  factory Match.fromJson(Object? json) {
    final Map<String, Object?> map = readObject(json);
    return Match(
      id: readString(map, 'id'),
      eventId: readString(map, 'eventId'),
      squadId: readString(map, 'squadId'),
      round: readString(map, 'round'),
      opponent: readString(map, 'opponent'),
      scheduledAt: readDateTime(map, 'scheduledAt'),
      format: readString(map, 'format'),
      status: MatchStatus.fromWire(readString(map, 'status')),
      stations: readStringList(map, 'stations'),
      readyCount: readInt(map, 'readyCount'),
      teamSize: readInt(map, 'teamSize'),
    );
  }

  final String id;
  final String eventId;
  final String squadId;
  final String round;
  final String opponent;
  final DateTime scheduledAt;
  final String format;
  final MatchStatus status;

  /// Station assignment shared with the event after check-in.
  final List<String> stations;

  /// Number of squad players confirmed ready; recalculated by the server.
  final int readyCount;

  final int teamSize;

  /// Whether the whole team is confirmed ready.
  bool get isFullyReady => readyCount >= teamSize;
}
