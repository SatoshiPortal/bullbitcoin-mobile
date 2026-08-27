import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';

/// Reads default Bitcoin wallet fingerprints from metadata only.
final class GetDefaultBitcoinWalletFingerprintsUsecase {
  final WalletRepository _wallets;

  const GetDefaultBitcoinWalletFingerprintsUsecase(this._wallets);

  Future<List<String>> execute({Environment? environment}) =>
      _wallets.getDefaultBitcoinWalletFingerprints(environment: environment);
}
