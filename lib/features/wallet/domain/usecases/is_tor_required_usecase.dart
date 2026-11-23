import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../repositories/wallet_reader_repository.dart';
import '../wallet_failure.dart';

class IsTorRequiredUsecase {
  final WalletReaderRepository _wallets;

  const IsTorRequiredUsecase(this._wallets);

  @useResult
  Future<Result<bool, WalletFailure>> execute() async =>
      switch (await _wallets.getDefaultMainnetBitcoinWallets()) {
        Ok(:final value) => Ok(
          value.isNotEmpty && value.first.latestEncryptedBackup != null,
        ),
        Err(:final failure) => Err(failure),
      };
}
