import 'parsing.dart';
import 'player.dart';

/// A squad registered for an event.
class Squad {
  const Squad({required this.id, required this.name, required this.players});

  /// Parses a squad payload, throwing [FormatException] when it is malformed.
  factory Squad.fromJson(Object? json) {
    final Map<String, Object?> map = readObject(json);
    final Object? players = map['players'];
    if (players is! List) {
      throw const FormatException('Expected "players" to be an array.');
    }
    return Squad(
      id: readString(map, 'id'),
      name: readString(map, 'name'),
      players: <Player>[
        for (final Object? player in players) Player.fromJson(player),
      ],
    );
  }

  final String id;
  final String name;
  final List<Player> players;

  /// Number of players confirmed ready by the server.
  int get readyCount => players.where((Player player) => player.isReady).length;
}
