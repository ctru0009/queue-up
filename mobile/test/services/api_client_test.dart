import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:queue_up/models/match.dart';
import 'package:queue_up/services/api_client.dart';

const Map<String, Object?> eventPayload = <String, Object?>{
  'id': 'event-valorant-friday-lan',
  'name': 'Valorant Friday LAN',
  'game': 'Valorant',
  'venue': 'Nexus Box Hill',
  'startsAt': '2026-09-18T19:00:00+10:00',
  'format': '5v5 • BO1',
  'registrationStatus': 'open',
  'checkedIn': false,
  'checkedInAt': null,
  'stations': <String>[],
  'squadId': 'squad-five-stack',
  'matchId': 'match-round-2',
};

const Map<String, Object?> matchPayload = <String, Object?>{
  'id': 'match-round-2',
  'eventId': 'event-valorant-friday-lan',
  'squadId': 'squad-five-stack',
  'round': 'Round 2',
  'opponent': 'Team Nexus',
  'scheduledAt': '2026-09-18T19:45:00+10:00',
  'format': 'BO1',
  'status': 'scheduled',
  'stations': <String>[],
  'readyCount': 4,
  'teamSize': 5,
};

const Map<String, Object?> squadPayload = <String, Object?>{
  'id': 'squad-five-stack',
  'name': 'Five Stack',
  'players': <Object?>[
    <String, Object?>{
      'id': 'player-neonfox',
      'handle': 'NeonFox',
      'role': 'Duelist',
      'isCaptain': true,
      'isReady': true,
      'isCurrentUser': false,
    },
    <String, Object?>{
      'id': 'player-cong',
      'handle': 'Cong',
      'role': null,
      'isCaptain': false,
      'isReady': false,
      'isCurrentUser': true,
    },
  ],
};

/// Captures the requests issued through [ApiClient].
class _Recorder {
  final List<http.Request> requests = <http.Request>[];
  late final ApiClient client;

  _Recorder(Future<http.Response> Function(http.Request request) handler) {
    client = ApiClient(
      MockClient((http.Request request) {
        requests.add(request);
        return handler(request);
      }),
      Uri.parse('http://10.0.2.2:3000'),
    );
  }
}

http.Response jsonResponse(Object? body, {int status = 200}) => http.Response(
  jsonEncode(body),
  status,
  headers: <String, String>{'content-type': 'application/json; charset=utf-8'},
);

void main() {
  group('ApiClient requests', () {
    test('GET /events parses the summaries in order', () async {
      final recorder = _Recorder(
        (http.Request request) async => jsonResponse(<Object?>[
          eventPayload,
          <String, Object?>{...eventPayload, 'id': 'event-melbourne-rift-cup', 'squadId': null, 'matchId': null},
        ]),
      );

      final events = await recorder.client.getEvents();

      expect(events, hasLength(2));
      expect(events.first.id, 'event-valorant-friday-lan');
      expect(events.first.isFeatured, isTrue);
      expect(events.last.id, 'event-melbourne-rift-cup');
      expect(events.last.squadId, isNull);
      expect(recorder.requests.single.method, 'GET');
      expect(recorder.requests.single.url.toString(), 'http://10.0.2.2:3000/events');
    });

    test('encodes resource ids as path segments', () async {
      final recorder = _Recorder(
        (http.Request request) async => jsonResponse(eventPayload),
      );

      await recorder.client.getEvent('event/with space');

      expect(
        recorder.requests.single.url.toString(),
        'http://10.0.2.2:3000/events/event%2Fwith%20space',
      );
    });

    test('GET /squads/:squadId parses nested players', () async {
      final recorder = _Recorder(
        (http.Request request) async => jsonResponse(squadPayload),
      );

      final squad = await recorder.client.getSquad('squad-five-stack');

      expect(squad.name, 'Five Stack');
      expect(squad.players, hasLength(2));
      expect(squad.players.last.handle, 'Cong');
      expect(squad.players.last.role, isNull);
      expect(squad.players.last.isCurrentUser, isTrue);
      expect(squad.readyCount, 1);
      expect(recorder.requests.single.url.toString(), 'http://10.0.2.2:3000/squads/squad-five-stack');
    });

    test('GET /matches/:matchId parses the status enum', () async {
      final recorder = _Recorder(
        (http.Request request) async => jsonResponse(matchPayload),
      );

      final match = await recorder.client.getMatch('match-round-2');

      expect(match.status, MatchStatus.scheduled);
      expect(match.readyCount, 4);
      expect(match.teamSize, 5);
    });

    test('POST check-in returns the changed event and match', () async {
      final recorder = _Recorder(
        (http.Request request) async => jsonResponse(<String, Object?>{
          'event': <String, Object?>{...eventPayload, 'checkedIn': true, 'stations': <String>['B11']},
          'match': <String, Object?>{...matchPayload, 'stations': <String>['B11']},
        }),
      );

      final response = await recorder.client.checkIn('event-valorant-friday-lan');

      expect(response.event.checkedIn, isTrue);
      expect(response.event.stations, <String>['B11']);
      expect(response.match.stations, <String>['B11']);
      expect(recorder.requests.single.method, 'POST');
      expect(
        recorder.requests.single.url.toString(),
        'http://10.0.2.2:3000/events/event-valorant-friday-lan/check-in',
      );
      expect(recorder.requests.single.body, isEmpty);
    });

    test('POST ready returns the changed match and squad', () async {
      final recorder = _Recorder(
        (http.Request request) async => jsonResponse(<String, Object?>{
          'match': <String, Object?>{...matchPayload, 'status': 'ready', 'readyCount': 5},
          'squad': squadPayload,
        }),
      );

      final response = await recorder.client.markReady('match-round-2');

      expect(response.match.status, MatchStatus.ready);
      expect(response.match.readyCount, 5);
      expect(response.squad.name, 'Five Stack');
      expect(recorder.requests.single.method, 'POST');
      expect(
        recorder.requests.single.url.toString(),
        'http://10.0.2.2:3000/matches/match-round-2/ready',
      );
    });
  });

  group('ApiClient failures', () {
    test('surfaces the safe message and code from an error body', () async {
      final recorder = _Recorder(
        (http.Request request) async => jsonResponse(
          <String, Object?>{
            'error': 'CHECK_IN_REQUIRED',
            'message': 'Check in before marking ready.',
          },
          status: 409,
        ),
      );

      expect(
        () => recorder.client.markReady('match-round-2'),
        throwsA(
          isA<ApiException>()
              .having((ApiException e) => e.code, 'code', 'CHECK_IN_REQUIRED')
              .having((ApiException e) => e.message, 'message', 'Check in before marking ready.'),
        ),
      );
    });

    test('falls back to generic copy for a non-JSON error body', () async {
      final recorder = _Recorder(
        (http.Request request) async => http.Response(
          '<html>Internal Server Error</html>',
          500,
          headers: <String, String>{'content-type': 'text/html'},
        ),
      );

      expect(
        () => recorder.client.getEvents(),
        throwsA(
          isA<ApiException>()
              .having((ApiException e) => e.code, 'code', isNull)
              .having(
                (ApiException e) => e.message,
                'message',
                'Something went wrong. Please try again.',
              ),
        ),
      );
    });

    test('rejects a 2xx response that is not JSON', () async {
      final recorder = _Recorder(
        (http.Request request) async => http.Response(
          'ok',
          200,
          headers: <String, String>{'content-type': 'text/plain'},
        ),
      );

      expect(() => recorder.client.getEvents(), throwsA(isA<ApiException>()));
    });

    test('rejects a malformed JSON body', () async {
      final recorder = _Recorder(
        (http.Request request) async => http.Response(
          '{"events": [',
          200,
          headers: <String, String>{'content-type': 'application/json'},
        ),
      );

      expect(() => recorder.client.getEvents(), throwsA(isA<ApiException>()));
    });

    test('rejects a body with the wrong root shape', () async {
      final recorder = _Recorder(
        (http.Request request) async => jsonResponse(<String, Object?>{'events': <Object?>[]}),
      );

      expect(() => recorder.client.getEvents(), throwsA(isA<ApiException>()));
    });

    test('rejects an unknown match status', () async {
      final recorder = _Recorder(
        (http.Request request) async => jsonResponse(<String, Object?>{...matchPayload, 'status': 'paused'}),
      );

      expect(() => recorder.client.getMatch('match-round-2'), throwsA(isA<ApiException>()));
    });

    test('wraps a transport failure in safe copy', () async {
      final recorder = _Recorder(
        (http.Request request) async => throw http.ClientException('connection refused'),
      );

      expect(
        () => recorder.client.getEvents(),
        throwsA(
          isA<ApiException>().having(
            (ApiException e) => e.message,
            'message',
            'Something went wrong. Please try again.',
          ),
        ),
      );
    });

    test('times out after five seconds without retrying', () async {
      int calls = 0;
      final recorder = _Recorder((http.Request request) async {
        calls++;
        await Future<void>.delayed(const Duration(milliseconds: 5300));
        return jsonResponse(<Object?>[]);
      });

      final Stopwatch stopwatch = Stopwatch()..start();
      await expectLater(recorder.client.getEvents(), throwsA(isA<ApiException>()));
      stopwatch.stop();

      expect(calls, 1, reason: 'the client must not retry automatically');
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 5, milliseconds: 250)));
    }, timeout: const Timeout(Duration(seconds: 20)));
  });
}
