import 'dart:async';

import 'package:flutter/material.dart';
import 'package:queue_up/formatters.dart';
import 'package:queue_up/models/event.dart';
import 'package:queue_up/models/match.dart';
import 'package:queue_up/models/player.dart';
import 'package:queue_up/models/squad.dart';
import 'package:queue_up/state/request_state.dart';
import 'package:queue_up/state/tournament_controller.dart';
import 'package:queue_up/widgets/resource_state_view.dart';

/// Match details with the check-in-gated readiness action.
class MatchScreen extends StatefulWidget {
  const MatchScreen({
    super.key,
    required this.controller,
    required this.matchId,
  });

  final TournamentController controller;
  final String matchId;

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> with ResourceStaleBannerHost {
  bool _routeIsCurrent = true;

  @override
  void initState() {
    super.initState();
    // Load only after the first frame: notifying listeners while an incoming
    // route builds would mark other mounted screens dirty mid-build.
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (mounted) {
        _loadIfNeeded();
      }
    });
  }

  void _loadIfNeeded() {
    final TournamentController controller = widget.controller;
    if (controller.match(widget.matchId) == null &&
        !controller.stateForMatch(widget.matchId).isLoading) {
      unawaited(_load());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Depending on the modal route keeps this screen informed when it becomes
    // current again, so its notice is restored if another screen cleared it.
    _routeIsCurrent = ModalRoute.of(context)?.isCurrent ?? true;
    _syncStaleBanner();
  }

  Future<void> _load() async {
    await widget.controller.loadMatch(widget.matchId);
    if (!mounted) {
      return;
    }
    _syncStaleBanner();
  }

  /// Shows the stale notice only while a cached match is on screen.
  void _syncStaleBanner() {
    final TournamentController controller = widget.controller;
    final RequestState state = controller.stateForMatch(widget.matchId);
    syncStaleBanner(
      stale: state.hasFailure && controller.match(widget.matchId) != null,
      message: state.message ?? refreshFailureMessage,
      onRetry: _load,
      force: _routeIsCurrent,
    );
  }

  Future<void> _markReady() async {
    final bool succeeded = await widget.controller.markReady(widget.matchId);
    if (!mounted || succeeded) {
      return;
    }
    final RequestState state = widget.controller.stateForReady(widget.matchId);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(state.message ?? mutationFailureMessage)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (BuildContext context, Widget? child) {
        final Match? match = widget.controller.match(widget.matchId);
        return Scaffold(
          appBar: AppBar(title: Text(match?.round ?? 'Round 2')),
          body: _body(context, match),
        );
      },
    );
  }

  Widget _body(BuildContext context, Match? match) {
    if (match == null) {
      final RequestState state = widget.controller.stateForMatch(widget.matchId);
      if (state.hasFailure) {
        return ResourceFatalView(
          message: state.message ?? loadFailureMessage,
          onRetry: _load,
        );
      }
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: <Widget>[
          _headline(context, match),
          const SizedBox(height: 24),
          ..._action(context, match),
          const SizedBox(height: 24),
          _infoCard(context, match),
        ],
      ),
    );
  }

  Widget _headline(BuildContext context, Match match) {
    final ThemeData theme = Theme.of(context);
    final Squad? squad = widget.controller.squad(match.squadId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '${squad?.name ?? 'Five Stack'} vs ${match.opponent}',
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        _statusChip(context, match.status.label, _statusIcon(match.status)),
      ],
    );
  }

  /// The single readiness action for this match.
  List<Widget> _action(BuildContext context, Match match) {
    final ThemeData theme = Theme.of(context);
    final TournamentController controller = widget.controller;
    final Squad? squad = controller.squad(match.squadId);
    // The event owns check-in state; station assignment on the match is the
    // fallback signal when the event detail is not cached on this route.
    final Event? event = controller.eventDetail(match.eventId);
    final bool checkedIn = event?.checkedIn ?? match.stations.isNotEmpty;
    // Readiness is server-authoritative: the squad carries the current player's
    // flag when it is cached, and a fully ready match implies it otherwise.
    final bool readyConfirmed =
        _currentPlayer(squad)?.isReady ?? match.isFullyReady;
    final bool pending = controller.stateForReady(widget.matchId).isLoading;

    if (readyConfirmed) {
      return <Widget>[
        Card.filled(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: <Widget>[
                Icon(Icons.check_circle, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Text('Ready ✓', style: theme.textTheme.titleMedium),
              ],
            ),
          ),
        ),
      ];
    }

    final bool canMarkReady =
        checkedIn && !pending && match.status == MatchStatus.scheduled;
    return <Widget>[
      SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: canMarkReady ? _markReady : null,
          child: pending
              ? _pendingLabel(context, "I'm Ready")
              : const Text("I'm Ready"),
        ),
      ),
      if (!checkedIn) ...<Widget>[
        const SizedBox(height: 8),
        Text(
          'Check in before marking ready.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ];
  }

  Widget _infoCard(BuildContext context, Match match) {
    final String stations = match.stations.isEmpty
        ? 'Assigned after check-in'
        : formatStations(match.stations);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: <Widget>[
            _infoRow(context, 'Scheduled', formatDateTime(match.scheduledAt)),
            _infoRow(context, 'Format', match.format),
            _infoRow(context, 'Stations', stations),
            _infoRow(
              context,
              'Readiness',
              '${match.readyCount}/${match.teamSize}',
            ),
            _infoRow(context, 'Status', match.status.label),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(BuildContext context, String label, String value) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }
}

Player? _currentPlayer(Squad? squad) {
  if (squad == null) {
    return null;
  }
  for (final Player player in squad.players) {
    if (player.isCurrentUser) {
      return player;
    }
  }
  return null;
}

IconData _statusIcon(MatchStatus status) {
  return switch (status) {
    MatchStatus.scheduled => Icons.schedule,
    MatchStatus.ready => Icons.check_circle_outline,
    MatchStatus.inProgress => Icons.play_circle_outline,
    MatchStatus.complete => Icons.flag_outlined,
  };
}

Widget _statusChip(BuildContext context, String label, IconData icon) {
  return Chip(
    avatar: Icon(icon, size: 18),
    label: Text(label),
    visualDensity: VisualDensity.compact,
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );
}

/// Inline progress shown inside a disabled CTA while a mutation is in flight.
Widget _pendingLabel(BuildContext context, String label) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      SizedBox(
        height: 16,
        width: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      const SizedBox(width: 12),
      Text(label),
    ],
  );
}
