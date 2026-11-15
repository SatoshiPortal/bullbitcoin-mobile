import 'package:primitives/primitives.dart';

import '../domain/quick_action.dart';
import '../domain/quick_actions_failure.dart';
import '../domain/quick_actions_repository.dart';
import 'quick_actions_model.dart';

final class QuickActionsRepositoryImpl implements QuickActionsRepository {
  const QuickActionsRepositoryImpl(this._storage);

  static const key = 'quick_actions';
  final QuickActionsStorage _storage;

  @override
  Future<Result<QuickActionSelection?, QuickActionsFailure>> load() async {
    try {
      final raw = await _storage.read(key);
      return Ok(
        raw == null ? null : QuickActionsModel.decode(raw).toSelection(),
      );
    } on Exception {
      return const Err(QuickActionsStorageFailure('read'));
    }
  }

  @override
  Future<Result<void, QuickActionsFailure>> save(
    QuickActionSelection selection,
  ) async {
    try {
      await _storage.write(
        key,
        QuickActionsModel.fromSelection(selection).encode(),
      );
      return const Ok(null);
    } on Exception {
      return const Err(QuickActionsStorageFailure('write'));
    }
  }

  @override
  Future<Result<void, QuickActionsFailure>> reset() async {
    try {
      await _storage.remove(key);
      return const Ok(null);
    } on Exception {
      return const Err(QuickActionsStorageFailure('remove'));
    }
  }
}
