import 'package:flutter_test/flutter_test.dart';
import 'package:queue_up/models/match.dart';

const Map<String, Object?> scheduledMatch = <String, Object?>{
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

const Map<String, Object?> readyMatch = <String, Object?>{
  'id': 'match-round-2',
  'eventId': 'event-valorant-friday-lan',
  'squadId': 'squad-five-stack',
  'round': 'Round 2',
  'opponent': 'Team Nexus',
  'scheduledAt': '2026-09-18T19:45:00+10:00',
  'format': 'BO1',
  'status': 'ready',
  'stations': <String>['B11', 'B12', 'B13', 'B14', 'B15'],
  'readyCount': 5,
  'teamSize': 5,
};

void main() {
  group('MatchStatus', () {
    test('maps every wire value to its enum value', () {
      expect(MatchStatus.fromWire('scheduled'), MatchStatus.scheduled);
      expect(MatchStatus.fromWire('ready'), MatchStatus.ready);
      expect(MatchStatus.fromWire('in_progress'), MatchStatus.inProgress);
      expect(MatchStatus.fromWire('complete'), MatchStatus.complete);
    });

    test('round-trips every enum value through its wire value', () {
      for (final MatchStatus status in MatchStatus.values) {
        expect(MatchStatus.fromWire(status.wireValue), status);
      }
      expect(
        MatchStatus.values.map((MatchStatus status) => status.wireValue),
        <String>['scheduled', 'ready', 'in_progress', 'complete'],
      );
    });

    test('exposes display labels', () {
      expect(MatchStatus.scheduled.label, 'Scheduled');
      expect(MatchStatus.ready.label, 'Ready');
      expect(MatchStatus.inProgress.label, 'In Progress');
      expect(MatchStatus.complete.label, 'Complete');
    });

    test('rejects an unknown wire value', () {
      expect(() => MatchStatus.fromWire('paused'), throwsFormatException);
      expect(() => MatchStatus.fromWire('in-progress'), throwsFormatException);
      expect(() => MatchStatus.fromWire(''), throwsFormatException);
    });
  });

  group('Match.fromJson', () {
    test('parses a scheduled match before check-in', () {
      final match = Match.fromJson(scheduledMatch);

      expect(match.id, 'match-round-2');
      expect(match.eventId, 'event-valorant-friday-lan');
      expect(match.squadId, 'squad-five-stack');
      expect(match.round, 'Round 2');
      expect(match.opponent, 'Team Nexus');
      expect(match.scheduledAt, DateTime.parse('2026-09-18T19:45:00+10:00'));
      expect(match.format, 'BO1');
      expect(match.status, MatchStatus.scheduled);
      expect(match.status.wireValue, 'scheduled');
      expect(match.stations, isEmpty);
      expect(match.readyCount, 4);
      expect(match.teamSize, 5);
      expect(match.isFullyReady, isFalse);
    });

    test('parses a ready match after check-in and readiness', () {
      final match = Match.fromJson(readyMatch);

      expect(match.status, MatchStatus.ready);
      expect(match.stations, <String>['B11', 'B12', 'B13', 'B14', 'B15']);
      expect(match.readyCount, 5);
      expect(match.isFullyReady, isTrue);
    });

    test('throws FormatException for an unknown status value', () {
      final payload = Map<String, Object?>.of(scheduledMatch)..['status'] = 'paused';

      expect(() => Match.fromJson(payload), throwsFormatException);
    });

    test('throws FormatException for malformed fields', () {
      expect(() => Match.fromJson(<Object?>[]), throwsFormatException);
      expect(
        () => Match.fromJson(Map<String, Object?>.of(scheduledMatch)..remove('round')),
        throwsFormatException,
      );
      expect(
        () => Match.fromJson(Map<String, Object?>.of(scheduledMatch)..['readyCount'] = 'four'),
        throwsFormatException,
      );
      expect(
        () => Match.fromJson(Map<String, Object?>.of(scheduledMatch)..['scheduledAt'] = 'yesterday'),
        throwsFormatException,
      );
      expect(
        () => Match.fromJson(Map<String, Object?>.of(scheduledMatch)..['stations'] = <Object?>[11]),
        throwsFormatException,
      );
    });
  });
}
