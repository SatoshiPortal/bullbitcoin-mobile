import 'package:bb_mobile/features/wallet/domain/repositories/wallet_reader_repository.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/features/wallet/domain/wallet_failure.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

/// Re-reads one known wallet without synchronizing or loading the catalogue.
class ReadWalletUsecase {
  final WalletReaderRepository _wallet;

  const ReadWalletUsecase(this._wallet);

  @useResult
  Future<Result<Wallet, WalletFailure>> execute(String walletId) =>
      _wallet.getWallet(walletId);
}
