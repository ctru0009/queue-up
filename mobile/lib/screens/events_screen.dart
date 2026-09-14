import 'dart:async';

import 'package:flutter/material.dart';
import 'package:queue_up/formatters.dart';
import 'package:queue_up/models/event.dart';
import 'package:queue_up/screens/event_detail_screen.dart';
import 'package:queue_up/state/request_state.dart';
import 'package:queue_up/state/tournament_controller.dart';
import 'package:queue_up/widgets/resource_state_view.dart';

/// Events list: deterministic summaries with the featured event first.
class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key, required this.controller});

  final TournamentController controller;

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen>
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
    if (controller.eventSummaries.isEmpty && !controller.eventsState.isLoading) {
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
    await widget.controller.loadEvents();
    if (!mounted) {
      return;
    }
    _syncStaleBanner();
  }

  /// Shows the stale notice only while cached summaries are on screen.
  void _syncStaleBanner() {
    final TournamentController controller = widget.controller;
    final RequestState state = controller.eventsState;
    syncStaleBanner(
      stale: state.hasFailure && controller.eventSummaries.isNotEmpty,
      message: state.message ?? refreshFailureMessage,
      onRetry: _load,
      force: _routeIsCurrent,
    );
  }

  void _openEvent(String eventId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => EventDetailScreen(
          controller: widget.controller,
          eventId: eventId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (BuildContext context, Widget? child) {
        final ThemeData theme = Theme.of(context);
        return Scaffold(
          appBar: AppBar(
            toolbarHeight: 72,
            title: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('QueueUp', style: theme.textTheme.titleLarge),
                Text(
                  'Your next LAN starts here.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          body: _body(context),
        );
      },
    );
  }

  Widget _body(BuildContext context) {
    final TournamentController controller = widget.controller;
    if (controller.eventSummaries.isEmpty) {
      final RequestState state = controller.eventsState;
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
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount: controller.eventSummaries.length,
        itemBuilder: (BuildContext context, int index) {
          final Event summary = controller.eventSummaries[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _EventCard(
              event: summary,
              onTap: () => _openEvent(summary.id),
            ),
          );
        },
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event, required this.onTap});

  final Event event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool featured = event.isFeatured;
    final bool checkedIn = event.checkedIn;
    final Widget body = InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                if (featured)
                  _statusChip(context, 'Your event', Icons.star_outline),
                if (featured)
                  _statusChip(
                    context,
                    checkedIn ? 'Checked in' : 'Not checked in',
                    checkedIn
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
            const SizedBox(height: 12),
            Text(event.name, style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              event.game,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            _infoRow(context, Icons.location_on_outlined, event.venue),
            const SizedBox(height: 6),
            _infoRow(context, Icons.schedule, formatDateTime(event.startsAt)),
            const SizedBox(height: 6),
            _infoRow(context, Icons.military_tech_outlined, event.format),
          ],
        ),
      ),
    );

    return featured
        ? Card.filled(clipBehavior: Clip.antiAlias, child: body)
        : Card.outlined(clipBehavior: Clip.antiAlias, child: body);
  }

  Widget _infoRow(BuildContext context, IconData icon, String value) {
    final ThemeData theme = Theme.of(context);
    return Row(
      children: <Widget>[
        Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
      ],
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
