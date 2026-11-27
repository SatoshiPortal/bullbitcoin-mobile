import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/storage.dart' show ViewId;

import '../domain/views_failure.dart';
import '../domain/views_port.dart';
import 'views_state.dart';

/// The list of views and its commands. It keeps no business rule: the port's
/// answer is the truth, and every command ends by reading it again.
final class ViewsCubit extends Cubit<ViewsState> {
  final ViewsPort _port;
  late final StreamSubscription<void> _subscription;

  ViewsCubit(this._port) : super(const ViewsState()) {
    _subscription = _port.changes.listen((_) => _refresh());
    _refresh();
  }

  void _refresh() {
    if (isClosed) return;
    emit(state.copyWith(views: _port.views, active: _port.active));
  }

  Future<void> activate(ViewId id) => _command(() => _port.activate(id));

  Future<void> create(String name) => _command(() => _port.create(name));

  Future<void> rename(ViewId id, String name) =>
      _command(() => _port.rename(id, name));

  Future<void> delete(ViewId id) => _command(() => _port.delete(id));

  Future<void> setBackground(bool enabled) =>
      _command(() => _port.setBackground(enabled));

  void dismissFailure() => emit(state.copyWith(failure: () => null));

  Future<void> _command(
    Future<Result<Object?, ViewsFailure>> Function() run,
  ) async {
    if (state.busy) return;
    emit(state.copyWith(busy: true, failure: () => null));
    final result = await run();
    if (isClosed) return;
    emit(
      state.copyWith(
        views: _port.views,
        active: _port.active,
        busy: false,
        failure: () => switch (result) {
          Err(:final failure) => failure,
          Ok() => null,
        },
      ),
    );
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}
