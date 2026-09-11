import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_descriptor_port.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/delete_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/reserve_bull_owned_bip48_accounts_usecase.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/domain/import_watch_only_failure.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/watch_only_wallet_entity.dart';
import 'package:meta/meta.dart';

class ImportWatchOnlyDescriptorUsecase {
  final BitcoinDescriptorPort _descriptorPort;
  final ReserveBullOwnedBip48AccountsUsecase _reserveBip48AccountsUsecase;
  final DeleteWalletUsecase _deleteWalletUsecase;

  ImportWatchOnlyDescriptorUsecase(
    this._descriptorPort,
    this._reserveBip48AccountsUsecase,
    this._deleteWalletUsecase,
  );

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
      final reserved = await _reserveBip48AccountsUsecase.execute(
        network: watchOnlyDescriptor.network,
        signers: watchOnlyDescriptor.signers,
      );
      if (reserved case Err()) {
        await _deleteWalletUsecase.execute(walletId: wallet.id);
        return const Err(ImportFailedFailure());
      }
      return Ok(wallet);
    } on Exception catch (_, st) {
      // Descriptor parser errors can contain key material.
      log.warning('Failed to import watch-only descriptor', trace: st);
      return const Err(ImportFailedFailure());
    }
  }
}
