import 'package:ark/ark.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/usecases/read_ark_home_usecase.dart';

final class ArkHomeCubit extends Cubit<ArkSnapshot?> {
  final ReadArkHomeUsecase _read;
  int _generation = 0;
  ArkHomeCubit(this._read) : super(null);

  Future<void> load() async {
    if (isClosed) return;
    final generation = ++_generation;
    emit(null);
    final snapshot = await _read.execute();
    if (!isClosed && generation == _generation) emit(snapshot);
  }

  @override
  Future<void> close() {
    ++_generation;
    return super.close();
  }
}
