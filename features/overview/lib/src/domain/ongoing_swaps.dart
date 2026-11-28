import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart';
import 'package:swaps/swaps.dart';

/// Reads the swaps Home can show, newest first. A read failure is not evidence
/// that there are no swaps in progress.
abstract interface class OngoingSwaps {
  factory OngoingSwaps(SwapStore store) = _OngoingSwaps;

  Future<Result<List<Swap>, OngoingSwapsFailure>> read();
}

sealed class OngoingSwapsFailure extends Failure {
  const OngoingSwapsFailure();
}

final class OngoingSwapsUnavailableFailure extends OngoingSwapsFailure {
  const OngoingSwapsUnavailableFailure();
}

final class _OngoingSwaps implements OngoingSwaps {
  final SwapStore _store;

  const _OngoingSwaps(this._store);

  @override
  Future<Result<List<Swap>, OngoingSwapsFailure>> read() async {
    switch (await _store.ongoing()) {
      case Ok(:final value):
        return Ok(
          value.where((swap) => !swap.isUnfunded).toList()
            ..sort((a, b) => b.creationTime.compareTo(a.creationTime)),
        );
      case Err(:final failure):
        log.warning('Ongoing swaps unavailable (${failure.runtimeType})');
        return const Err(OngoingSwapsUnavailableFailure());
    }
  }
}
