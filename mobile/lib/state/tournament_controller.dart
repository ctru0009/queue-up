import 'package:flutter/foundation.dart';

import '../models/api_responses.dart';
import '../models/event.dart';
import '../models/match.dart';
import '../models/squad.dart';
import '../services/api_client.dart';
import '../services/queue_up_api.dart';
import 'request_state.dart';

/// Owns the QueueUp resource caches and their request states.
///
/// Every method returns success instead of throwing into widgets, notifies
/// listeners when a request starts and finishes, and never replaces confirmed
/// data except with a server response. Request state is tracked per resource:
/// a mutation never marks GET data stale, and one screen failing never obscures
/// another.
class TournamentController extends ChangeNotifier {
  TournamentController(this._api);

  static const String _eventsKey = 'events';

  final QueueUpApi _api;

  List<Event> _eventSummaries = <Event>[];
  final Map<String, Event> _eventDetailsById = <String, Event>{};
  final Map<String, Squad> _squadsById = <String, Squad>{};
  final Map<String, Match> _matchesById = <String, Match>{};
  final Map<String, RequestState> _requestStates = <String, RequestState>{};

  /// Confirmed event summaries, featured event first.
  ///
  /// The list is the controller cache; callers must treat it as read-only.
  List<Event> get eventSummaries => _eventSummaries;

  /// Cached event detail, or `null` when it has not loaded.
  Event? eventDetail(String id) => _eventDetailsById[id];

  /// Cached squad, or `null` when it has not loaded.
  Squad? squad(String id) => _squadsById[id];

  /// Cached match, or `null` when it has not loaded.
  Match? match(String id) => _matchesById[id];

  /// Request state of the event summary list.
  RequestState get eventsState => _stateFor(_eventsKey);

  /// Request state of one event detail.
  RequestState stateForEvent(String id) => _stateFor('event:$id');

  /// Request state of one squad.
  RequestState stateForSquad(String id) => _stateFor('squad:$id');

  /// Request state of one match.
  RequestState stateForMatch(String id) => _stateFor('match:$id');

  /// Request state of the check-in mutation for [eventId].
  RequestState stateForCheckIn(String eventId) => _stateFor('checkIn:$eventId');

  /// Request state of the ready mutation for [matchId].
  RequestState stateForReady(String matchId) => _stateFor('ready:$matchId');

  /// Loads the event summaries, replacing the cache on success.
  Future<bool> loadEvents() => _load<List<Event>>(
        key: _eventsKey,
        hasCache: () => _eventSummaries.isNotEmpty,
        fetch: _api.getEvents,
        store: (List<Event> events) => _eventSummaries = events,
      );

  /// Loads one event detail, replacing its cache on success.
  Future<bool> loadEvent(String id) => _load<Event>(
        key: 'event:$id',
        hasCache: () => _eventDetailsById.containsKey(id),
        fetch: () => _api.getEvent(id),
        store: (Event event) => _eventDetailsById[id] = event,
      );

  /// Loads one squad, replacing its cache on success.
  Future<bool> loadSquad(String id) => _load<Squad>(
        key: 'squad:$id',
        hasCache: () => _squadsById.containsKey(id),
        fetch: () => _api.getSquad(id),
        store: (Squad squad) => _squadsById[id] = squad,
      );

  /// Loads one match, replacing its cache on success.
  Future<bool> loadMatch(String id) => _load<Match>(
        key: 'match:$id',
        hasCache: () => _matchesById.containsKey(id),
        fetch: () => _api.getMatch(id),
        store: (Match match) => _matchesById[id] = match,
      );

  /// Checks the current player in and stores every entity the server changed.
  Future<bool> checkIn(String eventId) => _mutate('checkIn:$eventId', () async {
        final CheckInResponse response = await _api.checkIn(eventId);
        _eventDetailsById[eventId] = response.event;
        _matchesById[response.match.id] = response.match;
        _replaceSummary(response.event);
      });

  /// Marks the current player ready and stores every entity the server changed.
  Future<bool> markReady(String matchId) => _mutate('ready:$matchId', () async {
        final ReadyResponse response = await _api.markReady(matchId);
        _matchesById[response.match.id] = response.match;
        _squadsById[response.squad.id] = response.squad;
      });

  /// Runs one GET-backed load with its own request state.
  Future<bool> _load<T>({
    required String key,
    required bool Function() hasCache,
    required Future<T> Function() fetch,
    required void Function(T value) store,
  }) async {
    final bool cached = hasCache();
    _setState(
      key,
      RequestState(
        status: cached ? RequestStatus.refreshing : RequestStatus.loading,
      ),
    );
    notifyListeners();

    try {
      final T value = await fetch();
      store(value);
      _setState(key, RequestState.idle);
      notifyListeners();
      return true;
    } catch (error) {
      _logFailure(key, error);
      _setState(
        key,
        RequestState(
          status: RequestStatus.error,
          message: cached ? refreshFailureMessage : loadFailureMessage,
        ),
      );
      notifyListeners();
      return false;
    }
  }

  /// Runs one mutation with its own request state, separate from GET state.
  Future<bool> _mutate(String key, Future<void> Function() action) async {
    _setState(key, const RequestState(status: RequestStatus.loading));
    notifyListeners();

    try {
      await action();
      _setState(key, RequestState.idle);
      notifyListeners();
      return true;
    } catch (error) {
      _logFailure(key, error);
      _setState(
        key,
        RequestState(status: RequestStatus.error, message: _mutationCopy(error)),
      );
      notifyListeners();
      return false;
    }
  }

  /// Replaces the summary entry for [event] so list cards stay confirmed.
  void _replaceSummary(Event event) {
    final int index =
        _eventSummaries.indexWhere((Event summary) => summary.id == event.id);
    if (index < 0) {
      return;
    }
    final List<Event> updated = List<Event>.of(_eventSummaries);
    updated[index] = event;
    _eventSummaries = updated;
  }

  RequestState _stateFor(String key) => _requestStates[key] ?? RequestState.idle;

  void _setState(String key, RequestState state) {
    _requestStates[key] = state;
  }

  /// Safe copy for a failed mutation: the server message when there is one.
  String _mutationCopy(Object error) {
    if (error is ApiException && error.message.trim().isNotEmpty) {
      return error.message;
    }
    return mutationFailureMessage;
  }

  /// Logs the failing request in debug builds only; never logs response bodies.
  void _logFailure(String key, Object error) {
    if (!kDebugMode) {
      return;
    }
    debugPrint('TournamentController $key failed: ${error.runtimeType}');
  }
}
