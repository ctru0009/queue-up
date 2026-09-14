/// Lifecycle of one controller request.
enum RequestStatus { idle, loading, refreshing, error }

/// Shown when a refresh fails while confirmed data stays on screen.
const String refreshFailureMessage =
    'Unable to refresh. Showing the last loaded data.';

/// Shown when a resource fails to load and nothing is cached for it.
const String loadFailureMessage =
    'Unable to load this data. Check the API and try again.';

/// Fallback copy for a failed mutation with no safe server message.
const String mutationFailureMessage = 'Something went wrong. Please try again.';

/// The state of one resource request or mutation.
///
/// Request state is per resource: one screen loading or failing never obscures
/// an unrelated screen. [message] always carries safe, user-facing copy.
class RequestState {
  const RequestState({this.status = RequestStatus.idle, this.message});

  final RequestStatus status;

  /// Safe user-facing copy for the current state; `null` unless failed.
  final String? message;

  /// The state of a resource that has not been requested yet.
  static const RequestState idle = RequestState();

  /// Whether a first load is in flight.
  bool get isLoading => status == RequestStatus.loading;

  /// Whether a refresh is in flight while cached data stays visible.
  bool get isRefreshing => status == RequestStatus.refreshing;

  /// Whether the last request for this resource failed.
  bool get hasFailure => status == RequestStatus.error;
}
