import 'package:ark/ark.dart';
import 'package:primitives/primitives.dart';

import '../repositories/ark_repository.dart';

/// The server's minimum Board amount from the last observation, as guidance:
/// the server still enforces its current minimum when the Board is quoted.
final class ReadArkBoardMinimumUsecase {
  final ArkRepository _repository;
  const ReadArkBoardMinimumUsecase(this._repository);

  /// Null when no observation of this account carries server information.
  Future<Sats?> execute(ArkAccountId account) async =>
      switch (await _repository.read(account)) {
        Ok(:final value) when value.account == account =>
          value.serverInfo?.minimumBoard,
        _ => null,
      };
}
