import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:primitives/primitives.dart';

import '../data/quick_actions_repository_impl.dart';
import '../domain/quick_action.dart';
import '../domain/quick_actions_failure.dart';
import '../domain/quick_actions_repository.dart';

final class QuickActionsState {
  const QuickActionsState({
    required this.available,
    this.selection,
    this.initialized = false,
    this.saving = false,
    this.draft,
    this.revision = 0,
  });
  final Set<QuickAction> available;
  final QuickActionSelection? selection;
  final bool initialized;
  final bool saving;
  final QuickActionSelection? draft;
  final int revision;
}

final class QuickActionsCubit extends Cubit<QuickActionsState> {
  QuickActionsCubit({
    required QuickActionsStorage storage,
    required this._warning,
    required Stream<bool> exchangeVisible,
  }) : _repository = QuickActionsRepositoryImpl(storage),
       super(QuickActionsState(available: _available(false))) {
    _visibility = exchangeVisible.listen(
      (visible) {
        _applyVisibility(visible);
      },
      onDone: () {
        if (!_firstVisibility.isCompleted) _firstVisibility.complete();
      },
      onError: (Object error) {
        _warning(
          'Could not observe quick action visibility; hiding exchange actions',
        );
        _applyVisibility(false);
      },
    );
  }

  void _applyVisibility(bool visible) {
    if (isClosed) return;
    if (!_firstVisibility.isCompleted) _firstVisibility.complete();
    emit(
      QuickActionsState(
        available: _available(visible),
        selection: state.selection,
        initialized: state.initialized,
        saving: state.saving,
        draft: state.draft,
        revision: state.revision,
      ),
    );
  }

  final _firstVisibility = Completer<void>();
  final QuickActionsRepository _repository;
  final void Function(String) _warning;
  late final StreamSubscription<bool> _visibility;
  Future<void> _pendingWrite = Future.value();
  int _generation = 0;
  static Set<QuickAction> _available(bool visible) => Set.unmodifiable(
    QuickAction.values.where(
      (action) =>
          visible ||
          !{
            QuickAction.buy,
            QuickAction.sell,
            QuickAction.pay,
            QuickAction.exchange,
          }.contains(action),
    ),
  );

  Future<QuickActionSelection?> load() async {
    await _firstVisibility.future;
    if (isClosed) return state.selection;
    if (state.initialized) return state.selection;
    final generation = _generation;
    final result = await _repository.load();
    if (isClosed) return state.selection;
    if (_generation != generation) {
      await _pendingWrite;
      if (!isClosed && !state.initialized) return load();
      return state.selection;
    }
    QuickActionSelection? selection;
    switch (result) {
      case Ok(:final value):
        selection = value;
      case Err():
        _warning('Could not read quick actions preference; using defaults');
    }
    emit(
      QuickActionsState(
        available: state.available,
        selection: selection,
        initialized: true,
        draft: selection ?? QuickActionSelection(QuickActionsLayout.defaults),
        revision: state.revision,
      ),
    );
    return selection;
  }

  Future<Result<void, QuickActionsFailure>> save(
    QuickActionSelection selection,
  ) => _enqueue(() => _repository.save(selection), selection);
  Future<Result<void, QuickActionsFailure>> reset() =>
      _enqueue(_repository.reset, null);
  Future<Result<void, QuickActionsFailure>> _enqueue(
    Future<Result<void, QuickActionsFailure>> Function() operation,
    QuickActionSelection? selection,
  ) {
    _generation++;
    final result = _pendingWrite.then((_) async {
      final previous = state.draft;
      if (!isClosed) {
        emit(
          QuickActionsState(
            available: state.available,
            selection: state.selection,
            initialized: state.initialized,
            saving: true,
            draft:
                selection ?? QuickActionSelection(QuickActionsLayout.defaults),
            revision: state.revision,
          ),
        );
      }
      final outcome = await operation();
      if (!isClosed) {
        final succeeded = outcome is Ok<void, QuickActionsFailure>;
        emit(
          QuickActionsState(
            available: state.available,
            selection: succeeded ? selection : state.selection,
            initialized: succeeded || state.initialized,
            draft: succeeded
                ? (selection ??
                      QuickActionSelection(QuickActionsLayout.defaults))
                : previous,
            revision: state.revision + (succeeded ? 1 : 0),
          ),
        );
      }
      return outcome;
    });
    _pendingWrite = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  @override
  Future<void> close() async {
    await _visibility.cancel();
    await super.close();
    if (!_firstVisibility.isCompleted) _firstVisibility.complete();
  }
}
