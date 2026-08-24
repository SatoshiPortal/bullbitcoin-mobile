import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_descriptor_port.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/domain/import_watch_only_failure.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/watch_only_wallet_entity.dart';
import 'package:meta/meta.dart';

class ImportWatchOnlyDescriptorUsecase {
  final BitcoinDescriptorPort _descriptorPort;

  ImportWatchOnlyDescriptorUsecase(this._descriptorPort);

  /// Maps failures from the core descriptor boundary to the feature's
  /// sanitized [ImportWatchOnlyFailure].
  @useResult
  Future<Result<Wallet, ImportWatchOnlyFailure>> execute({
    required WatchOnlyDescriptorEntity watchOnlyDescriptor,
  }) async {
    try {
      final wallet = await _descriptorPort.importDescriptor(
        descriptor: watchOnlyDescriptor.descriptor,
        network: watchOnlyDescriptor.network,
        label: watchOnlyDescriptor.label,
        signers: watchOnlyDescriptor.signers,
      );
      return Ok(wallet);
    } on Exception catch (_, st) {
      // Descriptor parser errors can contain key material.
      log.warning('Failed to import watch-only descriptor', trace: st);
      return const Err(ImportFailedFailure());
    }
  }
}
