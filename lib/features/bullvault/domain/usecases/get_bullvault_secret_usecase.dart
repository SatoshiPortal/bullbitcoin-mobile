import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:primitives/primitives.dart' show Fingerprint, Result, Ok, Err;
import 'package:secrets/secrets.dart' show Secret, Secrets;

class GetBullVaultSecretUsecase {
  final WalletRepository _wallets;
  final Secrets _secrets;

  const GetBullVaultSecretUsecase(this._wallets, this._secrets);

  Future<Result<Secret, BullVaultFailure>> execute({
    required Environment environment,
  }) async {
    final wallets = await _wallets.getWallets(
      environment: environment,
      onlyDefaults: true,
      onlyBitcoin: true,
    );
    final fingerprint = switch (wallets) {
      Ok(:final value) => value.firstOrNull?.singleLocalSeedFingerprint,
      Err() => null,
    };
    final id = Fingerprint.tryParse(fingerprint ?? '');
    if (id == null) return const Err(BullVaultCreationFailure());
    return (await _secrets.fetch(
      id,
    )).mapErr((_) => const BullVaultCreationFailure());
  }
}
