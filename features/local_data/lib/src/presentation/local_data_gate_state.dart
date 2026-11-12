import 'package:bull_local_data/src/domain/local_data_failure.dart';

/// What the gate screen shows. [failure] is why startup stopped; [resetFailure] is set when a reset did not complete.
final class LocalDataGateState {
  final LocalDataFailure failure;
  final bool busy;
  final LocalDataFailure? resetFailure;

  const LocalDataGateState({
    required this.failure,
    this.busy = false,
    this.resetFailure,
  });

  LocalDataGateState copyWith({
    bool? busy,
    LocalDataFailure? Function()? resetFailure,
  }) => LocalDataGateState(
    failure: failure,
    busy: busy ?? this.busy,
    resetFailure: resetFailure == null ? this.resetFailure : resetFailure(),
  );
}
