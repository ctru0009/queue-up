import 'package:flutter_test/flutter_test.dart';
import 'package:queue_up/models/api_responses.dart';
import 'package:queue_up/models/event.dart';
import 'package:queue_up/models/match.dart';
import 'package:queue_up/models/player.dart';
import 'package:queue_up/models/squad.dart';
import 'package:queue_up/services/api_client.dart';
import 'package:queue_up/services/queue_up_api.dart';
import 'package:queue_up/state/request_state.dart';
import 'package:queue_up/state/tournament_controller.dart';

const String _eventId = 'event-valorant-friday-lan';
const String _squadId = 'squad-five-stack';
const String _matchId = 'match-round-2';
const List<String> _stations = <String>['B11', 'B12', 'B13', 'B14', 'B15'];

Event _event({
  String id = _eventId,
  String name = 'Valorant Friday LAN',
  bool checkedIn = false,
  List<String> stations = const <String>[],
  DateTime? checkedInAt,
  String? squadId = _squadId,
  String? matchId = _matchId,
}) =>
    Event(
      id: id,
      name: name,
      game: 'Valorant',
      venue: 'Nexus Box Hill',
      startsAt: DateTime.utc(2026, 9, 18, 9),
      format: '5v5 • BO1',
      registrationStatus: 'open',
      checkedIn: checkedIn,
      stations: stations,
      checkedInAt: checkedInAt,
      squadId: squadId,
      matchId: matchId,
    );

List<Event> _seedSummaries() => <Event>[
      _event(),
      _event(
        id: 'event-melbourne-rift-cup',
        name: 'Melbourne Rift Cup',
        squadId: null,
        matchId: null,
      ),
      _event(
        id: 'event-cs2-saturday-clash',
        name: 'CS2 Saturday Clash',
        squadId: null,
        matchId: null,
      ),
    ];

Player _player(
  String id,
  String handle, {
  String? role,
  bool isCaptain = false,
  bool isReady = false,
  bool isCurrentUser = false,
}) =>
    Player(
      id: id,
      handle: handle,
      role: role,
      isCaptain: isCaptain,
      isReady: isReady,
      isCurrentUser: isCurrentUser,
    );

Squad _squad({bool currentUserReady = false}) => Squad(
      id: _squadId,
      name: 'Five Stack',
      players: <Player>[
        _player('player-neonfox', 'NeonFox', role: 'Duelist', isCaptain: true, isReady: true),
        _player('player-arclight', 'ArcLight', role: 'Controller', isReady: true),
        _player('player-cyphercat', 'CypherCat', role: 'Sentinel', isReady: true),
        _player('player-riftrunner', 'RiftRunner', role: 'Initiator', isReady: true),
        _player('player-cong', 'Cong', isReady: currentUserReady, isCurrentUser: true),
      ],
    );

Match _match({
  MatchStatus status = MatchStatus.scheduled,
  int readyCount = 4,
  List<String> stations = const <String>[],
}) =>
    Match(
      id: _matchId,
      eventId: _eventId,
      squadId: _squadId,
      round: 'Round 2',
      opponent: 'Team Nexus',
      scheduledAt: DateTime.utc(2026, 9, 18, 9, 45),
      format: 'BO1',
      status: status,
      stations: stations,
      readyCount: readyCount,
      teamSize: 5,
    );

Event _checkedInEvent() => _event(
      checkedIn: true,
      stations: _stations,
      checkedInAt: DateTime.utc(2026, 9, 18, 9, 23),
    );

Match _checkedInMatch() => _match(stations: _stations);

Match _fullyReadyMatch() =>
    _match(status: MatchStatus.ready, readyCount: 5, stations: _stations);

Squad _fullyReadySquad() => _squad(currentUserReady: true);

/// In-memory stand-in for the API; records calls and fails on demand.
class _FakeApi implements QueueUpApi {
  List<Event> events = _seedSummaries();
  Event event = _event();
  Squad squad = _squad();
  Match match = _match();

  Object? eventsFailure;
  Object? eventFailure;
  Object? squadFailure;
  Object? matchFailure;
  Object? checkInFailure;
  Object? readyFailure;

  final List<String> calls = <String>[];

  @override
  Future<List<Event>> getEvents() async {
    calls.add('getEvents');
    if (eventsFailure != null) {
      throw eventsFailure!;
    }
    return events;
  }

  @override
  Future<Event> getEvent(String id) async {
    calls.add('getEvent:$id');
    if (eventFailure != null) {
      throw eventFailure!;
    }
    return event;
  }

  @override
  Future<Squad> getSquad(String id) async {
    calls.add('getSquad:$id');
    if (squadFailure != null) {
      throw squadFailure!;
    }
    return squad;
  }

  @override
  Future<Match> getMatch(String id) async {
    calls.add('getMatch:$id');
    if (matchFailure != null) {
      throw matchFailure!;
    }
    return match;
  }

  @override
  Future<CheckInResponse> checkIn(String eventId) async {
    calls.add('checkIn:$eventId');
    if (checkInFailure != null) {
      throw checkInFailure!;
    }
    return CheckInResponse(event: _checkedInEvent(), match: _checkedInMatch());
  }

  @override
  Future<ReadyResponse> markReady(String matchId) async {
    calls.add('markReady:$matchId');
    if (readyFailure != null) {
      throw readyFailure!;
    }
    return ReadyResponse(match: _fullyReadyMatch(), squad: _fullyReadySquad());
  }
}

void main() {
  group('loadEvents', () {
    test('populates the summaries and notifies at start and completion', () async {
      final _FakeApi api = _FakeApi();
      final TournamentController controller = TournamentController(api);
      final List<RequestStatus> observed = <RequestStatus>[];
      controller.addListener(() => observed.add(controller.eventsState.status));

      expect(controller.eventsState.status, RequestStatus.idle);
      expect(controller.eventSummaries, isEmpty);

      final bool loaded = await controller.loadEvents();

      expect(loaded, isTrue);
      expect(controller.eventSummaries, hasLength(3));
      expect(controller.eventSummaries.first.name, 'Valorant Friday LAN');
      expect(controller.eventsState.status, RequestStatus.idle);
      expect(controller.eventsState.message, isNull);
      expect(observed, <RequestStatus>[RequestStatus.loading, RequestStatus.idle]);
      expect(api.calls, <String>['getEvents']);
    });

    test('reports a fatal first load and leaves the cache empty', () async {
      final _FakeApi api = _FakeApi()..eventsFailure = ApiException('Server exploded.');
      final TournamentController controller = TournamentController(api);

      final bool loaded = await controller.loadEvents();

      expect(loaded, isFalse);
      expect(controller.eventSummaries, isEmpty);
      expect(controller.eventsState.hasFailure, isTrue);
      expect(controller.eventsState.isLoading, isFalse);
      expect(controller.eventsState.message, loadFailureMessage);
    });

    test('keeps cached summaries on a failed refresh and clears it on success', () async {
      final _FakeApi api = _FakeApi();
      final TournamentController controller = TournamentController(api);
      await controller.loadEvents();
      final List<Event> cached = controller.eventSummaries;
      final List<RequestStatus> observed = <RequestStatus>[];
      controller.addListener(() => observed.add(controller.eventsState.status));

      api.eventsFailure = ApiException('API unreachable.');
      final bool refreshed = await controller.loadEvents();

      expect(refreshed, isFalse);
      expect(identical(controller.eventSummaries, cached), isTrue);
      expect(controller.eventSummaries, hasLength(3));
      expect(controller.eventSummaries.first.name, 'Valorant Friday LAN');
      expect(controller.eventsState.hasFailure, isTrue);
      expect(controller.eventsState.message, refreshFailureMessage);
      expect(observed, <RequestStatus>[RequestStatus.refreshing, RequestStatus.error]);

      api.eventsFailure = null;
      expect(await controller.loadEvents(), isTrue);
      expect(controller.eventsState.status, RequestStatus.idle);
      expect(controller.eventsState.message, isNull);
    });
  });

  group('per-resource state', () {
    test('an event detail failure leaves the events state untouched', () async {
      final _FakeApi api = _FakeApi()..eventFailure = ApiException('No detail.');
      final TournamentController controller = TournamentController(api);
      await controller.loadEvents();

      final bool loaded = await controller.loadEvent(_eventId);

      expect(loaded, isFalse);
      expect(controller.eventDetail(_eventId), isNull);
      expect(controller.stateForEvent(_eventId).hasFailure, isTrue);
      expect(controller.stateForEvent(_eventId).message, loadFailureMessage);
      expect(controller.eventsState.status, RequestStatus.idle);
      expect(controller.eventSummaries, hasLength(3));
    });

    test('squad and match load lazily and survive unrelated failures', () async {
      final _FakeApi api = _FakeApi();
      final TournamentController controller = TournamentController(api);

      expect(controller.squad(_squadId), isNull);
      expect(controller.match(_matchId), isNull);
      expect(controller.stateForSquad(_squadId).status, RequestStatus.idle);

      expect(await controller.loadSquad(_squadId), isTrue);
      expect(await controller.loadMatch(_matchId), isTrue);

      expect(controller.squad(_squadId)!.name, 'Five Stack');
      expect(controller.squad(_squadId)!.readyCount, 4);
      expect(controller.match(_matchId)!.round, 'Round 2');
      expect(controller.stateForSquad(_squadId).status, RequestStatus.idle);
      expect(controller.stateForMatch(_matchId).status, RequestStatus.idle);

      api.eventsFailure = ApiException('API unreachable.');
      expect(await controller.loadEvents(), isFalse);

      expect(controller.squad(_squadId)!.players, hasLength(5));
      expect(controller.match(_matchId)!.teamSize, 5);
      expect(controller.stateForSquad(_squadId).status, RequestStatus.idle);
      expect(controller.stateForMatch(_matchId).status, RequestStatus.idle);
    });
  });

  group('checkIn', () {
    test('replaces the cached event, match, and summary entry without refetching', () async {
      final _FakeApi api = _FakeApi();
      final TournamentController controller = TournamentController(api);
      await controller.loadEvents();
      await controller.loadEvent(_eventId);
      await controller.loadMatch(_matchId);
      await controller.loadSquad(_squadId);
      api.calls.clear();

      final bool confirmed = await controller.checkIn(_eventId);

      expect(confirmed, isTrue);
      expect(api.calls, <String>['checkIn:$_eventId']);
      expect(controller.eventDetail(_eventId)!.checkedIn, isTrue);
      expect(controller.eventDetail(_eventId)!.checkedInAt, DateTime.utc(2026, 9, 18, 9, 23));
      expect(controller.eventDetail(_eventId)!.stations, _stations);
      expect(controller.match(_matchId)!.stations, _stations);
      expect(controller.match(_matchId)!.readyCount, 4);
      expect(controller.eventSummaries.first.checkedIn, isTrue);
      expect(controller.eventSummaries.first.stations, _stations);
      expect(controller.eventSummaries, hasLength(3));
      expect(controller.stateForCheckIn(_eventId).status, RequestStatus.idle);
    });

    test('preserves confirmed state and GET state when it fails', () async {
      final _FakeApi api = _FakeApi();
      final TournamentController controller = TournamentController(api);
      await controller.loadEvents();
      await controller.loadEvent(_eventId);
      await controller.loadMatch(_matchId);
      final Event cachedEvent = controller.eventDetail(_eventId)!;
      final Match cachedMatch = controller.match(_matchId)!;

      api.checkInFailure = ApiException(
        'Check in before marking ready.',
        code: 'CHECK_IN_REQUIRED',
      );
      final bool confirmed = await controller.checkIn(_eventId);

      expect(confirmed, isFalse);
      expect(identical(controller.eventDetail(_eventId), cachedEvent), isTrue);
      expect(identical(controller.match(_matchId), cachedMatch), isTrue);
      expect(controller.eventDetail(_eventId)!.checkedIn, isFalse);
      expect(controller.match(_matchId)!.stations, isEmpty);
      expect(controller.eventSummaries.first.checkedIn, isFalse);
      expect(controller.stateForCheckIn(_eventId).hasFailure, isTrue);
      expect(controller.stateForCheckIn(_eventId).message, 'Check in before marking ready.');
      expect(controller.stateForEvent(_eventId).status, RequestStatus.idle);
      expect(controller.stateForMatch(_matchId).status, RequestStatus.idle);
      expect(controller.eventsState.status, RequestStatus.idle);
    });

    test('uses generic copy when the failure carries no safe server message', () async {
      final _FakeApi api = _FakeApi()..checkInFailure = Exception('socket closed');
      final TournamentController controller = TournamentController(api);

      expect(await controller.checkIn(_eventId), isFalse);
      expect(controller.stateForCheckIn(_eventId).message, mutationFailureMessage);
    });
  });

  group('markReady', () {
    test('replaces the cached match and squad without refetching', () async {
      final _FakeApi api = _FakeApi();
      final TournamentController controller = TournamentController(api);
      await controller.loadEvents();
      await controller.loadEvent(_eventId);
      await controller.loadSquad(_squadId);
      await controller.loadMatch(_matchId);
      api.calls.clear();

      final bool confirmed = await controller.markReady(_matchId);

      expect(confirmed, isTrue);
      expect(api.calls, <String>['markReady:$_matchId']);
      expect(controller.match(_matchId)!.status, MatchStatus.ready);
      expect(controller.match(_matchId)!.status.label, 'Ready');
      expect(controller.match(_matchId)!.readyCount, 5);
      expect(controller.match(_matchId)!.isFullyReady, isTrue);
      expect(controller.squad(_squadId)!.readyCount, 5);
      expect(
        controller.squad(_squadId)!.players.singleWhere((Player p) => p.isCurrentUser).isReady,
        isTrue,
      );
      expect(controller.stateForReady(_matchId).status, RequestStatus.idle);
      expect(controller.stateForMatch(_matchId).status, RequestStatus.idle);
      expect(controller.stateForSquad(_squadId).status, RequestStatus.idle);
    });

    test('preserves the cached match and squad when it fails', () async {
      final _FakeApi api = _FakeApi();
      final TournamentController controller = TournamentController(api);
      await controller.loadSquad(_squadId);
      await controller.loadMatch(_matchId);
      final Match cachedMatch = controller.match(_matchId)!;
      final Squad cachedSquad = controller.squad(_squadId)!;

      api.readyFailure = ApiException(
        'Check in before marking ready.',
        code: 'CHECK_IN_REQUIRED',
      );
      final bool confirmed = await controller.markReady(_matchId);

      expect(confirmed, isFalse);
      expect(identical(controller.match(_matchId), cachedMatch), isTrue);
      expect(identical(controller.squad(_squadId), cachedSquad), isTrue);
      expect(controller.match(_matchId)!.status, MatchStatus.scheduled);
      expect(controller.match(_matchId)!.readyCount, 4);
      expect(controller.squad(_squadId)!.readyCount, 4);
      expect(controller.stateForReady(_matchId).hasFailure, isTrue);
      expect(controller.stateForReady(_matchId).message, 'Check in before marking ready.');
      expect(controller.stateForMatch(_matchId).status, RequestStatus.idle);
      expect(controller.stateForSquad(_squadId).status, RequestStatus.idle);
    });
  });
}
