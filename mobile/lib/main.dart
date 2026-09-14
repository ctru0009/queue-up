import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'screens/events_screen.dart';
import 'services/api_client.dart';
import 'state/tournament_controller.dart';

/// Compile-time API base URL.
///
/// `10.0.2.2` is how the Android emulator reaches the host machine, so the
/// default works with a zero-argument `flutter run`. Point it at a LAN address
/// for a physical device:
///
/// ```sh
/// flutter run --dart-define=API_BASE_URL=http://192.168.1.20:3000
/// ```
const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:3000',
);

/// Turns [apiBaseUrl] into an absolute `http`/`https` [Uri].
///
/// A malformed `--dart-define=API_BASE_URL` fails fast on launch rather than
/// surfacing later as an unexplained request failure.
Uri _resolveBaseUri() {
  final Uri? uri = Uri.tryParse(apiBaseUrl);
  final bool isHttp = uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
  if (!isHttp || uri.host.isEmpty) {
    throw ArgumentError.value(
      apiBaseUrl,
      'API_BASE_URL',
      'Expected an absolute http or https URL, for example http://10.0.2.2:3000',
    );
  }
  return uri;
}

void main() {
  runApp(const QueueUpApp());
}

/// Composition root: owns the HTTP client, the [TournamentController], and the
/// fixed dark Material 3 theme, then injects the same controller into every
/// screen.
class QueueUpApp extends StatefulWidget {
  const QueueUpApp({super.key});

  @override
  State<QueueUpApp> createState() => _QueueUpAppState();
}

class _QueueUpAppState extends State<QueueUpApp> {
  late final http.Client _httpClient;
  late final TournamentController _controller;

  @override
  void initState() {
    super.initState();
    _httpClient = http.Client();
    _controller = TournamentController(ApiClient(_httpClient, _resolveBaseUri()));
    // Events load immediately on launch; other resources load when opened.
    unawaited(_controller.loadEvents());
  }

  @override
  void dispose() {
    _controller.dispose();
    _httpClient.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: Colors.cyan,
      brightness: Brightness.dark,
    );

    return MaterialApp(
      title: 'QueueUp',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: ThemeData(colorScheme: scheme, useMaterial3: true),
      home: EventsScreen(controller: _controller),
    );
  }
}
