/// Strict JSON readers shared by the QueueUp models.
///
/// Every reader throws a [FormatException] when the payload shape is wrong, so a
/// malformed server response fails parsing instead of leaking half-built models
/// into the UI. These helpers are internal to the model layer.
library;

/// Reads a required JSON object.
Map<String, Object?> readObject(Object? json) {
  if (json is Map<String, Object?>) {
    return json;
  }
  throw const FormatException('Expected a JSON object.');
}

/// Reads a required string field.
String readString(Map<String, Object?> json, String key) {
  final Object? value = json[key];
  if (value is String) {
    return value;
  }
  throw FormatException('Expected "$key" to be a string.');
}

/// Reads a string field that may be absent or `null`.
String? readNullableString(Map<String, Object?> json, String key) {
  final Object? value = json[key];
  if (value == null) {
    return null;
  }
  if (value is String) {
    return value;
  }
  throw FormatException('Expected "$key" to be a string or null.');
}

/// Reads a required boolean field.
bool readBool(Map<String, Object?> json, String key) {
  final Object? value = json[key];
  if (value is bool) {
    return value;
  }
  throw FormatException('Expected "$key" to be a boolean.');
}

/// Reads a required integer field.
int readInt(Map<String, Object?> json, String key) {
  final Object? value = json[key];
  if (value is int) {
    return value;
  }
  throw FormatException('Expected "$key" to be an integer.');
}

/// Reads a required ISO 8601 timestamp field.
DateTime readDateTime(Map<String, Object?> json, String key) {
  final DateTime? parsed = DateTime.tryParse(readString(json, key));
  if (parsed == null) {
    throw FormatException('Expected "$key" to be an ISO 8601 timestamp.');
  }
  return parsed;
}

/// Reads a timestamp field that may be absent or `null`.
DateTime? readNullableDateTime(Map<String, Object?> json, String key) {
  final String? raw = readNullableString(json, key);
  if (raw == null) {
    return null;
  }
  final DateTime? parsed = DateTime.tryParse(raw);
  if (parsed == null) {
    throw FormatException('Expected "$key" to be an ISO 8601 timestamp or null.');
  }
  return parsed;
}

/// Reads a required array of strings.
List<String> readStringList(Map<String, Object?> json, String key) {
  final Object? value = json[key];
  if (value is! List) {
    throw FormatException('Expected "$key" to be an array.');
  }
  return <String>[
    for (final Object? entry in value)
      if (entry is String) entry else throw FormatException('Expected every "$key" entry to be a string.'),
  ];
}
