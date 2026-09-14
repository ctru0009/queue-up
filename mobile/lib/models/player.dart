import 'parsing.dart';

/// A player in a tournament squad.
class Player {
  const Player({
    required this.id,
    required this.handle,
    required this.isCaptain,
    required this.isReady,
    required this.isCurrentUser,
    this.role,
  });

  /// Parses a player payload, throwing [FormatException] when it is malformed.
  factory Player.fromJson(Object? json) {
    final Map<String, Object?> map = readObject(json);
    return Player(
      id: readString(map, 'id'),
      handle: readString(map, 'handle'),
      role: readNullableString(map, 'role'),
      isCaptain: readBool(map, 'isCaptain'),
      isReady: readBool(map, 'isReady'),
      isCurrentUser: readBool(map, 'isCurrentUser'),
    );
  }

  final String id;
  final String handle;

  /// In-game role; `null` when the player has not set one.
  final String? role;

  final bool isCaptain;
  final bool isReady;

  /// Whether this player is the device user.
  final bool isCurrentUser;
}
