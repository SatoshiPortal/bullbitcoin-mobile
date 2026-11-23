import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:wallet_import/src/domain/import_failure.dart';
import 'package:wallet_import/src/domain/import_operations.dart';
import 'package:wallet_import/src/domain/watch_only/watch_only_wallet_entity.dart';
import 'package:wallet_import/src/domain/watch_only_input.dart';

class ImportWatchOnlyDescriptorUsecase {
  final ProvisionDescriptorWallet _provision;

  const ImportWatchOnlyDescriptorUsecase(this._provision);

  @useResult
  Future<Result<void, ImportWatchOnlyFailure>> execute({
    required WatchOnlyDescriptorEntity watchOnlyDescriptor,
  }) async {
    if (!watchOnlyDescriptor.descriptor.network.isBitcoin) {
      return const Err(InvalidFormatFailure());
    }
    return switch (watchOnlyDescriptor.validatedInput(
      watchOnlyDescriptor.network.env,
    )) {
      Ok(value: final WatchOnlyDescriptorInput descriptor) => _provision(
        descriptor: descriptor,
        signer: descriptor.network == BitcoinNetwork.regtest
            ? SignerEntity.none
            : watchOnlyDescriptor.signer,
        label: watchOnlyDescriptor.label,
      ),
      Err(:final failure) => Err(failure),
      Ok() => const Err(InvalidFormatFailure()),
    };
  }
}
