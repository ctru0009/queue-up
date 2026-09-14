import '../models/api_responses.dart';
import '../models/event.dart';
import '../models/match.dart';
import '../models/squad.dart';

/// The QueueUp API surface consumed by the tournament controller.
abstract class QueueUpApi {
  /// `GET /events` — event summaries, featured event first.
  Future<List<Event>> getEvents();

  /// `GET /events/:eventId` — event detail, including workflow state.
  Future<Event> getEvent(String id);

  /// `GET /squads/:squadId` — squad with per-player readiness.
  Future<Squad> getSquad(String id);

  /// `GET /matches/:matchId` — match with stations and readiness.
  Future<Match> getMatch(String id);

  /// `POST /events/:eventId/check-in` — idempotent check-in transaction.
  Future<CheckInResponse> checkIn(String eventId);

  /// `POST /matches/:matchId/ready` — mark the current player ready.
  Future<ReadyResponse> markReady(String matchId);
}
