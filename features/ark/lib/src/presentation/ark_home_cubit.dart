import 'package:ark/ark.dart';
import 'package:bloc/bloc.dart';

final class ArkHomeCubit extends Cubit<ArkSnapshot?> {
  final Future<ArkSnapshot?> Function() _read;
  int _generation = 0;
  ArkHomeCubit(this._read) : super(null);

  /// Reads home's observation again. By default the previous one is
  /// cleared first, so another account's balance is never shown meanwhile.
  /// [keep] leaves it on screen while the same open account is read again,
  /// so a refresh does not flash "unavailable".
  Future<void> load({bool keep = false}) async {
    if (isClosed) return;
    final generation = ++_generation;
    if (!keep) emit(null);
    final snapshot = await _read();
    if (!isClosed && generation == _generation) emit(snapshot);
  }

  @override
  Future<void> close() {
    ++_generation;
    return super.close();
  }
}
