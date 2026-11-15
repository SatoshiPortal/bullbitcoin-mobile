import 'package:bb_mobile/core/wallet/domain/bitcoin_send_port.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/features/address_view/domain/address_view_failure.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart' show Err, Ok, Result;

class FindAddressOwnerUsecase {
  final GetWalletsUsecase _getWalletsUsecase;
  final BitcoinSendPort _bitcoinSendPort;

  const FindAddressOwnerUsecase({
    required this._getWalletsUsecase,
    required this._bitcoinSendPort,
  });

  @useResult
  Future<Result<Wallet?, AddressViewFailure>> execute(String address) async {
    try {
      final List<Wallet> wallets;
      switch (await _getWalletsUsecase.execute(onlyBitcoin: true)) {
        case Ok(:final value):
          wallets = value;
        case Err(failure: NoWalletsFoundFailure()):
          return const Ok(null);
        case Err(:final failure):
          return Err(
            AddressViewOwnershipUnavailableFailure(
              failure.runtimeType.toString(),
            ),
          );
      }

      for (final wallet in wallets) {
        final isOwner = await _bitcoinSendPort.areAddressesOfWallet([
          address,
        ], walletId: wallet.id);
        if (isOwner) return Ok(wallet);
      }
      return const Ok(null);
    } catch (e) {
      log.warning(
        'Address explorer: ownership check failed (${e.runtimeType})',
      );
      return Err(AddressViewOwnershipUnavailableFailure('${e.runtimeType}'));
    }
  }
}
