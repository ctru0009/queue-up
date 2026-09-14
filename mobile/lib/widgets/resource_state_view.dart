import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Centered fatal state for a resource that has no cached data.
///
/// Shown inside a normal [Scaffold] so AppBar and navigation chrome stay
/// visible; [onRetry] reloads only the failed resource.
class ResourceFatalView extends StatelessWidget {
  const ResourceFatalView({
    super.key,
    required this.message,
    required this.onRetry,
    this.icon = Icons.cloud_off,
  });

  /// Concise generic copy; never raw exception text.
  final String message;

  /// Reloads the resource that failed.
  final VoidCallback onRetry;

  /// Standard Material icon describing the failure.
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 48, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hosts the persistent stale-data notice for one screen.
///
/// The notice is a non-dismissible [MaterialBanner] with a resource-specific
/// `Retry`, intended to sit directly below the AppBar. Screens call
/// [syncStaleBanner] only from state-change handlers — after an awaited load or
/// from [State.didChangeDependencies] — and never during [State.build]. The
/// messenger is touched only when the requested notice actually changes, and an
/// update requested while a build is in progress is deferred to the end of that
/// frame.
mixin ResourceStaleBannerHost<T extends StatefulWidget> on State<T> {
  bool _hasSynced = false;
  bool _applied = false;
  bool _requested = false;
  bool _forcePending = false;
  bool _deferred = false;
  String _message = '';
  VoidCallback? _onRetry;
  ScaffoldMessengerState? _messenger;

  /// Shows or clears this screen's stale notice.
  ///
  /// [stale] must be true only while cached content is still on screen and the
  /// last refresh for it failed. [message] is the controller's safe copy.
  /// [force] re-applies the requested notice even when it is already applied,
  /// which screens use when their route becomes current again after another
  /// screen cleared the messenger.
  void syncStaleBanner({
    required bool stale,
    required String message,
    required VoidCallback onRetry,
    bool force = false,
  }) {
    _requested = stale;
    _message = message;
    _onRetry = onRetry;
    if (_deferred || (_hasSynced && !force && _requested == _applied)) {
      return;
    }
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      _deferred = true;
      _forcePending = _forcePending || force;
      SchedulerBinding.instance.addPostFrameCallback((Duration _) {
        _deferred = false;
        final bool pendingForce = _forcePending;
        _forcePending = false;
        _applyStaleBanner(force: pendingForce);
      });
      return;
    }
    _applyStaleBanner(force: force);
  }

  void _applyStaleBanner({required bool force}) {
    if (!mounted) {
      return;
    }
    final bool firstSync = !_hasSynced;
    _hasSynced = true;
    if (!firstSync && !force && _requested == _applied) {
      return;
    }
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    _messenger = messenger;
    _applied = _requested;
    if (!_requested) {
      messenger.clearMaterialBanners();
      return;
    }
    messenger.showMaterialBanner(
      MaterialBanner(
        leading: Icon(
          Icons.sync_problem,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        content: Text(_message),
        actions: <Widget>[
          TextButton(
            onPressed: _onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    final ScaffoldMessengerState? messenger = _messenger;
    if (_applied && messenger != null) {
      _applied = false;
      SchedulerBinding.instance.addPostFrameCallback(
        (Duration _) => messenger.clearMaterialBanners(),
      );
    }
    super.dispose();
  }
}
