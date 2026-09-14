import 'parsing.dart';

/// A QueueUp tournament event.
///
/// One model serves both the `GET /events` summary payload and the
/// `GET /events/:eventId` detail payload; the workflow fields that only exist on
/// the detail payload ([checkedInAt], [stations], [squadId], [matchId]) are
/// nullable on the wire, never on the required core fields.
class Event {
  const Event({
    required this.id,
    required this.name,
    required this.game,
    required this.venue,
    required this.startsAt,
    required this.format,
    required this.registrationStatus,
    required this.checkedIn,
    required this.stations,
    this.checkedInAt,
    this.squadId,
    this.matchId,
  });

  /// Parses an event payload, throwing [FormatException] when it is malformed.
  factory Event.fromJson(Object? json) {
    final Map<String, Object?> map = readObject(json);
    return Event(
      id: readString(map, 'id'),
      name: readString(map, 'name'),
      game: readString(map, 'game'),
      venue: readString(map, 'venue'),
      startsAt: readDateTime(map, 'startsAt'),
      format: readString(map, 'format'),
      registrationStatus: readString(map, 'registrationStatus'),
      checkedIn: readBool(map, 'checkedIn'),
      stations: readStringList(map, 'stations'),
      checkedInAt: readNullableDateTime(map, 'checkedInAt'),
      squadId: readNullableString(map, 'squadId'),
      matchId: readNullableString(map, 'matchId'),
    );
  }

  final String id;
  final String name;
  final String game;
  final String venue;
  final DateTime startsAt;
  final String format;
  final String registrationStatus;

  /// Whether the current player has checked in at the venue.
  final bool checkedIn;

  /// Confirmed check-in timestamp; `null` before check-in.
  final DateTime? checkedInAt;

  /// Confirmed gaming-station assignment; empty before check-in.
  final List<String> stations;

  /// Squad owned by this event; non-null only for the featured event.
  final String? squadId;

  /// Match owned by this event; non-null only for the featured event.
  final String? matchId;

  /// Whether this event drives the check-in, squad, and match workflow.
  ///
  /// Derived from the payload relationships rather than a presentation flag.
  bool get isFeatured => squadId != null && matchId != null;
}
