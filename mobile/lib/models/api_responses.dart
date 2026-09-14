import 'event.dart';
import 'match.dart';
import 'parsing.dart';
import 'squad.dart';

/// Payload returned by `POST /events/:eventId/check-in`.
///
/// Check-in is a transaction: the server returns every entity it changed.
class CheckInResponse {
  const CheckInResponse({required this.event, required this.match});

  /// Parses a check-in response, throwing [FormatException] when malformed.
  factory CheckInResponse.fromJson(Object? json) {
    final Map<String, Object?> map = readObject(json);
    return CheckInResponse(
      event: Event.fromJson(map['event']),
      match: Match.fromJson(map['match']),
    );
  }

  final Event event;
  final Match match;
}

/// Payload returned by `POST /matches/:matchId/ready`.
///
/// The server recalculates the match readiness and returns the squad that owns it.
class ReadyResponse {
  const ReadyResponse({required this.match, required this.squad});

  /// Parses a ready response, throwing [FormatException] when malformed.
  factory ReadyResponse.fromJson(Object? json) {
    final Map<String, Object?> map = readObject(json);
    return ReadyResponse(
      match: Match.fromJson(map['match']),
      squad: Squad.fromJson(map['squad']),
    );
  }

  final Match match;
  final Squad squad;
}
