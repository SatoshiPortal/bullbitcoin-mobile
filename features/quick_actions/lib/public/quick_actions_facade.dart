import 'package:flutter/foundation.dart';
import 'package:primitives/primitives.dart';

import '../src/data/quick_actions_repository_impl.dart';
import '../src/domain/quick_action.dart';
import '../src/domain/quick_actions_failure.dart';
import '../src/domain/quick_actions_repository.dart';
import '../src/domain/usecases/load_quick_actions_usecase.dart';
import '../src/domain/usecases/reset_quick_actions_usecase.dart';
import '../src/domain/usecases/save_quick_actions_usecase.dart';

export '../src/domain/quick_actions_repository.dart' show QuickActionsStorage;
export '../src/domain/quick_action.dart';
export '../src/domain/quick_actions_failure.dart';
export '../src/presentation/quick_actions_fallback_delegate.dart';
export '../src/ui/quick_actions_row.dart';
export 'package:primitives/primitives.dart' show Result, Ok, Err;
export '../generated/l10n/quick_actions_localizations.dart';

/// Shared composition for the preference and its consumers.
final class QuickActionsFacade extends ChangeNotifier {
  factory QuickActionsFacade({
    required QuickActionsStorage storage,
    required void Function(String) warning,
  }) {
    final repository = QuickActionsRepositoryImpl(storage);
    return QuickActionsFacade._(
      LoadQuickActionsUsecase(repository),
      SaveQuickActionsUsecase(repository),
      ResetQuickActionsUsecase(repository),
      warning,
    );
  }

  QuickActionsFacade._(this._load, this._save, this._reset, this._warning);
  final LoadQuickActionsUsecase _load;
  final SaveQuickActionsUsecase _save;
  final ResetQuickActionsUsecase _reset;
  final void Function(String) _warning;
  QuickActionSelection? _selection;
  bool _initialized = false;
  int _generation = 0;

  /// The host can await [load] before mounting the row to avoid a loading gap.
  bool get initialized => _initialized;
  QuickActionSelection? get selection => _selection;

  Future<QuickActionSelection?> load() async {
    if (_initialized) return _selection;
    final generation = _generation;
    final result = await _load.execute();
    if (generation != _generation) return _selection;
    switch (result) {
      case Ok(:final value):
        _selection = value;
      case Err():
        _warning('Could not read quick actions preference; using defaults');
        _selection = null;
    }
    _initialized = true;
    notifyListeners();
    return _selection;
  }

  Future<Result<void, QuickActionsFailure>> save(
    QuickActionSelection selection,
  ) async {
    final result = await _save.execute(selection);
    if (result is Ok<void, QuickActionsFailure>) {
      _generation++;
      _selection = selection;
      _initialized = true;
      notifyListeners();
    }
    return result;
  }

  Future<Result<void, QuickActionsFailure>> reset() async {
    final result = await _reset.execute();
    if (result is Ok<void, QuickActionsFailure>) {
      _generation++;
      _selection = null;
      _initialized = true;
      notifyListeners();
    }
    return result;
  }
}
