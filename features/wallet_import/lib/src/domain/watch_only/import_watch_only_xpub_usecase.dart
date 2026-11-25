import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:provisioning/provisioning.dart';
import 'package:wallet_import/src/domain/import_failure.dart';
import 'package:wallet_import/src/domain/watch_only/import_watch_only_failure_mapping.dart';
import 'package:wallet_import/src/domain/watch_only/watch_only_wallet_entity.dart';
import 'package:wallet_import/src/domain/watch_only_input.dart';

class ImportWatchOnlyXpubUsecase {
  final WalletProvisioning _accounts;

  const ImportWatchOnlyXpubUsecase(this._accounts);

  @useResult
  Future<Result<void, ImportWatchOnlyFailure>> execute({
    required WatchOnlyXpubEntity watchOnlyXpub,
  }) async {
    if (!watchOnlyXpub.extendedPubkey.network.isBitcoin) {
      return const Err(InvalidFormatFailure());
    }
    switch (watchOnlyXpub.validatedInput(watchOnlyXpub.network.env)) {
      case Ok(value: final WatchOnlyXpubInput input):
        return (await _accounts.importXpub(
          xpub: input.pubkey,
          network: input.network,
          scriptType: input.scriptType,
          label: watchOnlyXpub.label,
        )).mapErr(importWatchOnlyFailure);
      case Err(:final failure):
        return Err(failure);
      case Ok():
        return const Err(InvalidFormatFailure());
    }
  }
}
