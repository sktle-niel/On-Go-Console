import 'dart:async';

/// A value that can be read now and watched for changes.
///
/// Every `watch*` method in `package:on_go_shared` is a Stream that has to
/// replay its current value to a new listener — a screen that subscribes after
/// the data changed must not sit empty waiting for the next change. This is
/// that behaviour, in one place, so the local services do not each reinvent it.
///
/// It also matches how the networked implementations will behave: fetch once,
/// then apply pushes.
class LiveValue<T> {
  LiveValue(this._value);

  T _value;
  final StreamController<T> _controller = StreamController<T>.broadcast();

  T get value => _value;

  /// Publishes [next] to every listener.
  void set(T next) {
    _value = next;
    if (!_controller.isClosed) _controller.add(next);
  }

  /// Recomputes and publishes — for state held elsewhere, where the value is
  /// derived rather than assigned.
  void refresh(T Function() compute) => set(compute());

  /// The current value, then every change.
  ///
  /// Multi-subscription: the returned stream can be listened to more than
  /// once, and each listener gets the value as it stands when *it* subscribes
  /// before any later change.
  ///
  /// That matters because of how the console resizes. Crossing a breakpoint
  /// makes [ConsoleShell] swap between two different arrangements, which tears
  /// the page body out of one element tree and re-inflates it into the other.
  /// A page that built its `StreamBuilder` once — anything that does not
  /// happen to rebuild on a layout change — hands the new builder the very
  /// stream the outgoing one is still holding, because deactivated elements
  /// are not disposed of until the end of the frame. With a single-
  /// subscription stream that second listen throws "Stream has already been
  /// listened to" and the page renders as a red error box instead of resizing.
  ///
  /// Written as a generator (`async*`) this was single-subscription, so every
  /// screen watching a value was one window drag away from that. Handing out
  /// a stream that tolerates the overlap fixes it for all of them at once,
  /// rather than each page having to know about it.
  Stream<T> get stream => Stream<T>.multi((listener) {
        listener.add(_value);
        final subscription = _controller.stream.listen(
          listener.add,
          onError: listener.addError,
          onDone: listener.close,
        );
        listener
          ..onCancel = subscription.cancel
          ..onPause = subscription.pause
          ..onResume = subscription.resume;
      });

  Future<void> dispose() => _controller.close();
}
