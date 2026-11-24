import 'package:wallet_import/src/domain/import_failure.dart';
import 'package:wallet_import/src/domain/watch_only/watch_only_wallet_entity.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:wallet_import/src/domain/watch_only_input.dart';

class ParseWatchOnlyInputUsecase {
  @useResult
  Future<Result<WatchOnlyWalletEntity, ImportWatchOnlyFailure>> execute(
    String input, {
    required NetworkEnv environment,
  }) async =>
      switch (await WatchOnlyInput.parse(input, environment: environment)) {
        Ok(:final value) => Ok(WatchOnlyWalletEntity.fromInput(value)),
        Err(failure: WatchOnlyNetworkMismatchFailure()) => const Err(
          NetworkMismatchFailure(),
        ),
        Err() => const Err(InvalidFormatFailure()),
      };
}
