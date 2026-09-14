import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/api_responses.dart';
import '../models/event.dart';
import '../models/match.dart';
import '../models/squad.dart';
import 'queue_up_api.dart';

/// Timeout applied to every QueueUp request.
const Duration _requestTimeout = Duration(seconds: 5);

/// Safe copy for failures that did not come from a structured API error body.
const String _genericFailureMessage = 'Something went wrong. Please try again.';

/// A failed QueueUp API request.
///
/// [message] is always safe, user-facing copy: either the message from the API's
/// structured error body or a generic sentence. Technical detail is logged in
/// debug builds only, never returned to callers.
class ApiException implements Exception {
  const ApiException(this.message, {this.code});

  /// Safe user-facing copy.
  final String message;

  /// Structured error code, present when the API returned an error body.
  final String? code;

  @override
  String toString() =>
      code == null ? 'ApiException: $message' : 'ApiException($code): $message';
}

/// HTTP implementation of [QueueUpApi].
///
/// The composition root injects both the shared `http.Client`, which it owns
/// (this class never creates, replaces, or closes it), and the API base URL.
class ApiClient implements QueueUpApi {
  ApiClient(this._httpClient, this._baseUrl);

  final http.Client _httpClient;
  final Uri _baseUrl;

  @override
  Future<List<Event>> getEvents() async {
    final Object? json = await _send(
      'GET',
      const <String>['events'],
      'GET /events',
    );
    return _parse('GET /events', () {
      if (json is! List) {
        throw const FormatException('Expected an array of events.');
      }
      return <Event>[
        for (final Object? entry in json) Event.fromJson(entry),
      ];
    });
  }

  @override
  Future<Event> getEvent(String id) async {
    const String operation = 'GET /events/:eventId';
    final Object? json = await _send('GET', <String>['events', id], operation);
    return _parse(operation, () => Event.fromJson(json));
  }

  @override
  Future<Squad> getSquad(String id) async {
    const String operation = 'GET /squads/:squadId';
    final Object? json = await _send('GET', <String>['squads', id], operation);
    return _parse(operation, () => Squad.fromJson(json));
  }

  @override
  Future<Match> getMatch(String id) async {
    const String operation = 'GET /matches/:matchId';
    final Object? json = await _send('GET', <String>['matches', id], operation);
    return _parse(operation, () => Match.fromJson(json));
  }

  @override
  Future<CheckInResponse> checkIn(String eventId) async {
    const String operation = 'POST /events/:eventId/check-in';
    final Object? json = await _send(
      'POST',
      <String>['events', eventId, 'check-in'],
      operation,
    );
    return _parse(operation, () => CheckInResponse.fromJson(json));
  }

  @override
  Future<ReadyResponse> markReady(String matchId) async {
    const String operation = 'POST /matches/:matchId/ready';
    final Object? json = await _send(
      'POST',
      <String>['matches', matchId, 'ready'],
      operation,
    );
    return _parse(operation, () => ReadyResponse.fromJson(json));
  }

  /// Performs one request and returns its decoded JSON body.
  ///
  /// Rejects non-2xx statuses and non-JSON bodies, mapping each failure to an
  /// [ApiException] carrying safe copy.
  Future<Object?> _send(
    String method,
    List<String> pathSegments,
    String operation,
  ) async {
    final Uri uri = _baseUrl.replace(pathSegments: pathSegments);

    final http.Response response;
    try {
      final Future<http.Response> request = method == 'POST'
          ? _httpClient.post(uri)
          : _httpClient.get(uri);
      response = await request.timeout(_requestTimeout);
    } catch (error) {
      _logFailure(operation, error);
      throw const ApiException(_genericFailureMessage);
    }

    final bool isJson = _isJson(response.headers['content-type']);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final ({String? code, String message})? error = isJson
          ? _safeErrorBody(response.body)
          : null;
      _logFailure(operation, 'HTTP ${response.statusCode}');
      if (error == null) {
        throw const ApiException(_genericFailureMessage);
      }
      throw ApiException(error.message, code: error.code);
    }

    if (!isJson) {
      _logFailure(operation, 'unexpected response content-type');
      throw const ApiException(_genericFailureMessage);
    }

    try {
      return jsonDecode(response.body);
    } on FormatException catch (error) {
      _logFailure(operation, error);
      throw const ApiException(_genericFailureMessage);
    }
  }

  /// Runs a model parse, converting shape failures into safe [ApiException]s.
  T _parse<T>(String operation, T Function() parse) {
    try {
      return parse();
    } on FormatException catch (error) {
      _logFailure(operation, error);
      throw const ApiException(_genericFailureMessage);
    } on TypeError catch (error) {
      _logFailure(operation, error);
      throw const ApiException(_genericFailureMessage);
    }
  }

  /// Extracts the safe message from a structured `{error, message}` body.
  ({String? code, String message})? _safeErrorBody(String body) {
    try {
      final Object? decoded = jsonDecode(body);
      if (decoded is Map<String, Object?>) {
        final Object? message = decoded['message'];
        final Object? code = decoded['error'];
        if (message is String && message.isNotEmpty) {
          return (
            code: code is String && code.isNotEmpty ? code : null,
            message: message,
          );
        }
      }
    } on FormatException {
      // Not a structured error body; fall back to generic copy.
    }
    return null;
  }

  bool _isJson(String? contentType) =>
      contentType != null &&
      contentType.toLowerCase().contains('application/json');

  /// Logs failure context in debug builds only; never logs response bodies.
  void _logFailure(String operation, Object error) {
    if (!kDebugMode) {
      return;
    }
    debugPrint(
      'ApiClient $operation failed: '
      '${error is String ? error : error.runtimeType}',
    );
  }
}
