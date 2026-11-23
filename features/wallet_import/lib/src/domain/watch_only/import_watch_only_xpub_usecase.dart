import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:wallet_import/src/domain/import_failure.dart';
import 'package:wallet_import/src/domain/import_operations.dart';
import 'package:wallet_import/src/domain/watch_only/watch_only_wallet_entity.dart';
import 'package:wallet_import/src/domain/watch_only_input.dart';

class ImportWatchOnlyXpubUsecase {
  final ProvisionXpubWallet _provision;

  const ImportWatchOnlyXpubUsecase(this._provision);

  @useResult
  Future<Result<void, ImportWatchOnlyFailure>> execute({
    required WatchOnlyXpubEntity watchOnlyXpub,
  }) async {
    if (!watchOnlyXpub.extendedPubkey.network.isBitcoin) {
      return const Err(InvalidFormatFailure());
    }
    return switch (watchOnlyXpub.validatedInput(watchOnlyXpub.network.env)) {
      Ok(value: final WatchOnlyXpubInput input) => _provision(
        xpub: input.pubkey,
        network: input.network,
        scriptType: input.scriptType,
        label: watchOnlyXpub.label,
      ),
      Err(:final failure) => Err(failure),
      Ok() => const Err(InvalidFormatFailure()),
    };
  }
}
