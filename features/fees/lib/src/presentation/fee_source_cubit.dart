import 'package:fees/fees.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:primitives/primitives.dart' show Err, Ok;

sealed class FeeSourceState {
  final FeeSource? source;

  const FeeSourceState(this.source);
}

final class FeeSourceLoading extends FeeSourceState {
  const FeeSourceLoading([super.source]);
}

final class FeeSourceSelected extends FeeSourceState {
  const FeeSourceSelected(FeeSource super.source);
}

final class FeeSourceFailed extends FeeSourceState {
  final FeesFailure failure;
  final FeeSource? attempted;

  const FeeSourceFailed(this.failure, [super.source, this.attempted]);
}

class FeeSourceCubit extends Cubit<FeeSourceState> {
  final Fees _fees;

  FeeSourceCubit(this._fees) : super(const FeeSourceLoading());

  Future<void> load() async {
    emit(const FeeSourceLoading());
    final result = await _fees.readSource();
    if (isClosed) return;
    emit(switch (result) {
      Ok(:final value) => FeeSourceSelected(value),
      Err(:final failure) => FeeSourceFailed(failure),
    });
  }

  Future<void> select(FeeSource source) async {
    final previous = state.source;
    if (state is FeeSourceLoading || previous == null || previous == source) {
      return;
    }
    emit(FeeSourceLoading(previous));
    final result = await _fees.saveSource(source);
    if (isClosed) return;
    emit(switch (result) {
      Ok() => FeeSourceSelected(source),
      Err(:final failure) => FeeSourceFailed(failure, previous, source),
    });
  }

  Future<void> retry() async {
    switch (state) {
      case FeeSourceFailed(attempted: final attempted?):
        await select(attempted);
      case FeeSourceFailed():
        await load();
      default:
        return;
    }
  }
}
