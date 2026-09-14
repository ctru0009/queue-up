import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:queue_up/models/event.dart';

const Map<String, Object?> featuredSummary = <String, Object?>{
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

const Map<String, Object?> checkedInDetail = <String, Object?>{
  'id': 'event-valorant-friday-lan',
  'name': 'Valorant Friday LAN',
  'game': 'Valorant',
  'venue': 'Nexus Box Hill',
  'startsAt': '2026-09-18T19:00:00+10:00',
  'format': '5v5 • BO1',
  'registrationStatus': 'open',
  'checkedIn': true,
  'checkedInAt': '2026-09-18T19:23:00+10:00',
  'stations': <String>['B11', 'B12', 'B13', 'B14', 'B15'],
  'squadId': 'squad-five-stack',
  'matchId': 'match-round-2',
};

const Map<String, Object?> secondarySummary = <String, Object?>{
  'id': 'event-melbourne-rift-cup',
  'name': 'Melbourne Rift Cup',
  'game': 'League of Legends',
  'venue': 'Southern Cross Gaming Hall',
  'startsAt': '2026-09-19T13:00:00+10:00',
  'format': '5v5 • BO1',
  'registrationStatus': 'open',
  'checkedIn': false,
  'checkedInAt': null,
  'stations': <String>[],
  'squadId': null,
  'matchId': null,
};

void main() {
  group('Event.fromJson', () {
    test('parses an event summary payload', () {
      final event = Event.fromJson(featuredSummary);

      expect(event.id, 'event-valorant-friday-lan');
      expect(event.name, 'Valorant Friday LAN');
      expect(event.game, 'Valorant');
      expect(event.venue, 'Nexus Box Hill');
      expect(event.startsAt, DateTime.parse('2026-09-18T19:00:00+10:00'));
      expect(event.startsAt.isUtc, isTrue);
      expect(event.format, '5v5 • BO1');
      expect(event.registrationStatus, 'open');
      expect(event.checkedIn, isFalse);
      expect(event.checkedInAt, isNull);
      expect(event.stations, isEmpty);
      expect(event.squadId, 'squad-five-stack');
      expect(event.matchId, 'match-round-2');
    });

    test('parses an event detail payload after check-in', () {
      final event = Event.fromJson(checkedInDetail);

      expect(event.checkedIn, isTrue);
      expect(event.checkedInAt, DateTime.parse('2026-09-18T19:23:00+10:00'));
      expect(event.stations, <String>['B11', 'B12', 'B13', 'B14', 'B15']);
    });

    test('parses the nullable workflow fields as null', () {
      final event = Event.fromJson(secondarySummary);

      expect(event.checkedInAt, isNull);
      expect(event.squadId, isNull);
      expect(event.matchId, isNull);
      expect(event.stations, isEmpty);
    });

    test('treats absent nullable workflow fields as null', () {
      final payload = Map<String, Object?>.of(featuredSummary)
        ..remove('checkedInAt')
        ..remove('squadId')
        ..remove('matchId');

      final event = Event.fromJson(payload);

      expect(event.checkedInAt, isNull);
      expect(event.squadId, isNull);
      expect(event.matchId, isNull);
    });

    test('parses stations as a List<String>', () {
      final event = Event.fromJson(checkedInDetail);

      expect(event.stations, isA<List<String>>());
      expect(event.stations.first, 'B11');
      expect(event.stations.last, 'B15');
    });

    test('parses a JSON document decoded from the wire', () {
      final decoded = jsonDecode(jsonEncode(featuredSummary));
      final event = Event.fromJson(decoded);

      expect(event.id, 'event-valorant-friday-lan');
      expect(event.squadId, 'squad-five-stack');
    });
  });

  group('Event.fromJson rejects malformed payloads', () {
    test('throws FormatException for a wrong root type', () {
      expect(() => Event.fromJson(<Object?>[]), throwsFormatException);
      expect(() => Event.fromJson('event'), throwsFormatException);
      expect(() => Event.fromJson(null), throwsFormatException);
    });

    test('throws FormatException for a missing required field', () {
      final payload = Map<String, Object?>.of(featuredSummary)..remove('name');

      expect(() => Event.fromJson(payload), throwsFormatException);
    });

    test('throws FormatException for a wrong field type', () {
      final payload = Map<String, Object?>.of(featuredSummary)..['game'] = 42;

      expect(() => Event.fromJson(payload), throwsFormatException);
    });

    test('throws FormatException for an invalid timestamp', () {
      final payload = Map<String, Object?>.of(featuredSummary)
        ..['startsAt'] = 'not-a-timestamp';

      expect(() => Event.fromJson(payload), throwsFormatException);
    });

    test('throws FormatException for a non-boolean checkedIn', () {
      final payload = Map<String, Object?>.of(featuredSummary)
        ..['checkedIn'] = 'yes';

      expect(() => Event.fromJson(payload), throwsFormatException);
    });

    test('throws FormatException when stations is not a list of strings', () {
      final notAList = Map<String, Object?>.of(featuredSummary)
        ..['stations'] = 'B11';
      final notOfStrings = Map<String, Object?>.of(featuredSummary)
        ..['stations'] = <Object?>['B11', 12];

      expect(() => Event.fromJson(notAList), throwsFormatException);
      expect(() => Event.fromJson(notOfStrings), throwsFormatException);
    });

    test('throws FormatException for a wrong nullable field type', () {
      final payload = Map<String, Object?>.of(featuredSummary)
        ..['squadId'] = 7;

      expect(() => Event.fromJson(payload), throwsFormatException);
    });
  });
}
