import 'dart:async';
import 'dart:ui';

import 'package:fl_clash/common/common.dart';

extension FutureExt<T> on Future<T> {
  Future<T> withTimeout({
    Duration? timeout,
    String? tag,
    VoidCallback? onLast,
    FutureOr<T> Function()? onTimeout,
  }) {
    final realTimeout = timeout ?? const Duration(minutes: 3);
    // S-09: Store timer reference to cancel on successful completion
    Timer? orphanTimer;
    orphanTimer = Timer(realTimeout + commonDuration, () {
      if (onLast != null) {
        onLast();
      }
    });
    return this.timeout(
      realTimeout,
      onTimeout: () async {
        // S-09: Cancel orphan timer since timeout already fired
        orphanTimer?.cancel();
        if (onTimeout != null) {
          return onTimeout();
        } else {
          throw TimeoutException('${tag ?? runtimeType} timeout');
        }
      },
    ).whenComplete(() {
      // S-09: Cancel orphan timer when future completes successfully
      orphanTimer?.cancel();
    });
  }
}

extension CompleterExt<T> on Completer<T> {
  void safeCompleter(T value) {
    if (isCompleted) {
      return;
    }
    complete(value);
  }
}
