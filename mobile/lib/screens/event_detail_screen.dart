import 'dart:async';

import 'package:flutter/material.dart';
import 'package:queue_up/formatters.dart';
import 'package:queue_up/models/event.dart';
import 'package:queue_up/screens/match_screen.dart';
import 'package:queue_up/screens/squad_screen.dart';
import 'package:queue_up/state/request_state.dart';
import 'package:queue_up/state/tournament_controller.dart';
import 'package:queue_up/widgets/resource_state_view.dart';

/// Event detail: hero information plus the featured check-in workflow.
///
/// Workflow state is always resolved from the controller's detail cache so a
/// confirmed check-in updates this route in place instead of showing a stale
/// summary captured during navigation.
class EventDetailScreen extends StatefulWidget {
  const EventDetailScreen({
    super.key,
    required this.controller,
    required this.eventId,
  });

  final TournamentController controller;
  final String eventId;

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen>
    with ResourceStaleBannerHost {
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
    if (controller.eventDetail(widget.eventId) == null &&
        !controller.stateForEvent(widget.eventId).isLoading) {
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
    await widget.controller.loadEvent(widget.eventId);
    if (!mounted) {
      return;
    }
    _syncStaleBanner();
  }

  /// Shows the stale notice only while a cached detail is on screen.
  void _syncStaleBanner() {
    final TournamentController controller = widget.controller;
    final RequestState state = controller.stateForEvent(widget.eventId);
    syncStaleBanner(
      stale: state.hasFailure && controller.eventDetail(widget.eventId) != null,
      message: state.message ?? refreshFailureMessage,
      onRetry: _load,
      force: _routeIsCurrent,
    );
  }

  Future<void> _checkIn() async {
    final bool succeeded = await widget.controller.checkIn(widget.eventId);
    if (!mounted || succeeded) {
      return;
    }
    _showMutationFailure(
      widget.controller.stateForCheckIn(widget.eventId).message,
    );
  }

  void _showMutationFailure(String? message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message ?? mutationFailureMessage)),
    );
  }

  void _openSquad(String squadId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => SquadScreen(
          controller: widget.controller,
          squadId: squadId,
        ),
      ),
    );
  }

  void _openMatch(String matchId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => MatchScreen(
          controller: widget.controller,
          matchId: matchId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (BuildContext context, Widget? child) {
        final TournamentController controller = widget.controller;
        final Event? detail = controller.eventDetail(widget.eventId);
        return Scaffold(
          appBar: AppBar(
            title: Text(detail?.name ?? _summary(controller)?.name ?? 'Event'),
          ),
          body: _body(context, detail),
        );
      },
    );
  }

  Widget _body(BuildContext context, Event? event) {
    if (event == null) {
      final RequestState state = widget.controller.stateForEvent(widget.eventId);
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
          _heroCard(context, event),
          if (event.isFeatured) ...<Widget>[
            const SizedBox(height: 16),
            _checkInSection(context, event),
            const SizedBox(height: 16),
            _navigationCard(
              context,
              icon: Icons.groups_outlined,
              title: 'My Squad',
              onTap: () => _openSquad(event.squadId!),
            ),
            const SizedBox(height: 12),
            _navigationCard(
              context,
              icon: Icons.sports_score,
              title: 'Upcoming Match',
              onTap: () => _openMatch(event.matchId!),
            ),
          ],
        ],
      ),
    );
  }

  /// Summary fallback for the AppBar title before the detail arrives.
  Event? _summary(TournamentController controller) {
    for (final Event event in controller.eventSummaries) {
      if (event.id == widget.eventId) {
        return event;
      }
    }
    return null;
  }

  Widget _heroCard(BuildContext context, Event event) {
    final ThemeData theme = Theme.of(context);
    final bool featured = event.isFeatured;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  Icons.sports_esports,
                  size: 44,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    event.name,
                    style: theme.textTheme.headlineSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                if (featured)
                  _statusChip(context, 'Your event', Icons.star_outline),
                if (featured)
                  _statusChip(
                    context,
                    event.checkedIn ? 'Checked in' : 'Not checked in',
                    event.checkedIn
                        ? Icons.check_circle_outline
                        : Icons.radio_button_unchecked,
                  ),
                if (!featured)
                  _statusChip(
                    context,
                    'Registration open',
                    Icons.how_to_reg_outlined,
                  ),
              ],
            ),
            const SizedBox(height: 20),
            _infoRow(
              context,
              Icons.videogame_asset_outlined,
              'Game',
              event.game,
            ),
            _infoRow(
              context,
              Icons.location_on_outlined,
              'Venue',
              event.venue,
            ),
            _infoRow(
              context,
              Icons.schedule,
              'Starts',
              formatDateTime(event.startsAt),
            ),
            _infoRow(
              context,
              Icons.military_tech_outlined,
              'Format',
              event.format,
            ),
          ],
        ),
      ),
    );
  }

  Widget _checkInSection(BuildContext context, Event event) {
    final ThemeData theme = Theme.of(context);
    if (event.checkedIn) {
      final String stations = formatStations(event.stations);
      return Card.filled(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(Icons.check_circle, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Checked in', style: theme.textTheme.titleMedium),
                    if (stations.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        'Stations $stations',
                        style: theme.textTheme.bodyLarge,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final bool pending = widget.controller
        .stateForCheckIn(widget.eventId)
        .isLoading;
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: pending ? null : _checkIn,
        child: pending
            ? _pendingLabel(context, 'Check In')
            : const Text('Check In'),
      ),
    );
  }

  Widget _navigationCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    final ThemeData theme = Theme.of(context);
    return Card.outlined(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: theme.colorScheme.primary),
        title: Text(title, style: theme.textTheme.titleMedium),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }

  Widget _infoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: theme.textTheme.bodyLarge),
          ),
        ],
      ),
    );
  }
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
