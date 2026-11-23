import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:provisioning/provisioning.dart';
import 'package:satoshifier/satoshifier.dart' show WatchOnlyDescriptorExtension;
import 'package:wallet_import/src/domain/import_failure.dart';
import 'package:wallet_import/src/domain/watch_only/import_watch_only_failure_mapping.dart';
import 'package:wallet_import/src/domain/watch_only/watch_only_wallet_entity.dart';
import 'package:wallet_import/src/domain/watch_only_input.dart';

class ImportWatchOnlyDescriptorUsecase {
  final WalletProvisioning _accounts;

  const ImportWatchOnlyDescriptorUsecase(this._accounts);

  @useResult
  Future<Result<void, ImportWatchOnlyFailure>> execute({
    required WatchOnlyDescriptorEntity watchOnlyDescriptor,
  }) async {
    if (!watchOnlyDescriptor.descriptor.network.isBitcoin) {
      return const Err(InvalidFormatFailure());
    }
    switch (watchOnlyDescriptor.validatedInput(
      watchOnlyDescriptor.network.env,
    )) {
      case Ok(value: final WatchOnlyDescriptorInput input):
        final descriptor = input.value;
        return (await _accounts.importDescriptor(
          WatchOnlyAccount(
            network: input.network,
            scriptType: input.scriptType,
            masterFingerprint: descriptor.masterFingerprint,
            pubkey: input.pubkey,
            descriptors: (
              external: descriptor.descriptor.external,
              internal: descriptor.descriptor.internal,
            ),
            signer: input.network == BitcoinNetwork.regtest
                ? SignerEntity.none
                : watchOnlyDescriptor.signer,
            signerDevice: input.signerDevice?.name,
            label: watchOnlyDescriptor.label,
          ),
        )).mapErr(importWatchOnlyFailure);
      case Err(:final failure):
        return Err(failure);
      case Ok():
        return const Err(InvalidFormatFailure());
    }
  }
}
