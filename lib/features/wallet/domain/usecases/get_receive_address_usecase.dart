import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:transaction_sync/read.dart';
import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_address_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';

class GetReceiveAddressUsecase {
  final WalletAddressRepository _walletAddressRepository;

  GetReceiveAddressUsecase({required this._walletAddressRepository});

  Future<WalletAddress> execute({
    required String walletId,
    bool generateNew = false,
  }) async {
    try {
      WalletAddress address;
      if (generateNew) {
        address = await _walletAddressRepository.generateNewReceiveAddress(
          walletId: walletId,
        );
      } else {
        address = await _walletAddressRepository.getLastRevealedReceiveAddress(
          walletId: walletId,
        );
      }

      return address;
    } on InvalidWalletAddressException {
      rethrow;
    } on WalletSnapshotException catch (e) {
      throw GetReceiveAddressException(e.failure.logCode, reported: true);
    } on Exception {
      throw GetReceiveAddressException('storage');
    }
  }
}

class GetReceiveAddressException extends BullException {
  final bool reported;
  GetReceiveAddressException(super.message, {this.reported = false});
}
