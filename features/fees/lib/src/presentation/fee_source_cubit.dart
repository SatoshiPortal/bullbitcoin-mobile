import 'package:fees/fees.dart' show FeeSource;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:primitives/primitives.dart' show Err, Ok;

import '../domain/fee_source_settings_failure.dart';
import '../domain/usecases/load_fee_source_usecase.dart';
import '../domain/usecases/save_fee_source_usecase.dart';

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
  final FeeSourceSettingsFailure failure;
  final FeeSource? attempted;

  const FeeSourceFailed(this.failure, [super.source, this.attempted]);
}

class FeeSourceCubit extends Cubit<FeeSourceState> {
  final LoadFeeSourceUsecase _loadSource;
  final SaveFeeSourceUsecase _saveSource;

  FeeSourceCubit({required this._loadSource, required this._saveSource})
    : super(const FeeSourceLoading());

  Future<void> load() async {
    emit(const FeeSourceLoading());
    final result = await _loadSource.execute();
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
    final result = await _saveSource.execute(source);
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
