import 'dart:async';

import 'package:flutter/material.dart';
import 'package:queue_up/models/player.dart';
import 'package:queue_up/models/squad.dart';
import 'package:queue_up/state/request_state.dart';
import 'package:queue_up/state/tournament_controller.dart';
import 'package:queue_up/widgets/resource_state_view.dart';

/// Squad roster with server-confirmed readiness for each player.
class SquadScreen extends StatefulWidget {
  const SquadScreen({
    super.key,
    required this.controller,
    required this.squadId,
  });

  final TournamentController controller;
  final String squadId;

  @override
  State<SquadScreen> createState() => _SquadScreenState();
}

class _SquadScreenState extends State<SquadScreen> with ResourceStaleBannerHost {
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
    if (controller.squad(widget.squadId) == null &&
        !controller.stateForSquad(widget.squadId).isLoading) {
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
    await widget.controller.loadSquad(widget.squadId);
    if (!mounted) {
      return;
    }
    _syncStaleBanner();
  }

  /// Shows the stale notice only while a cached squad is on screen.
  void _syncStaleBanner() {
    final TournamentController controller = widget.controller;
    final RequestState state = controller.stateForSquad(widget.squadId);
    syncStaleBanner(
      stale: state.hasFailure && controller.squad(widget.squadId) != null,
      message: state.message ?? refreshFailureMessage,
      onRetry: _load,
      force: _routeIsCurrent,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (BuildContext context, Widget? child) {
        final Squad? squad = widget.controller.squad(widget.squadId);
        return Scaffold(
          appBar: AppBar(title: Text(squad?.name ?? 'Five Stack')),
          body: _body(context, squad),
        );
      },
    );
  }

  Widget _body(BuildContext context, Squad? squad) {
    if (squad == null) {
      final RequestState state = widget.controller.stateForSquad(widget.squadId);
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
          _readinessCard(context, squad.readyCount, squad.players.length),
          const SizedBox(height: 16),
          for (final Player player in squad.players)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _PlayerCard(player: player),
            ),
        ],
      ),
    );
  }

  Widget _readinessCard(BuildContext context, int readyCount, int total) {
    final ThemeData theme = Theme.of(context);
    return Card.filled(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '$readyCount of $total ready',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: total == 0 ? 0 : readyCount / total,
                minHeight: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayerCard extends StatelessWidget {
  const _PlayerCard({required this.player});

  final Player player;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? role = player.role;
    final bool isReady = player.isReady;
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      Text(
                        player.handle,
                        style: theme.textTheme.titleMedium,
                      ),
                      if (player.isCaptain) _tagChip('Captain'),
                      if (player.isCurrentUser) _tagChip('You'),
                    ],
                  ),
                  if (role != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        role,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  isReady ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 20,
                  color: isReady
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  isReady ? 'Ready' : 'Not ready',
                  style: theme.textTheme.labelLarge,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Widget _tagChip(String label) {
  return Chip(
    label: Text(label),
    visualDensity: VisualDensity.compact,
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );
}
