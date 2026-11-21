import 'package:bb_mobile/features/bip85_entropy/public/bip85_parent.dart';
import 'package:bb_mobile/features/wallet/data/wallet_repository.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';

class ReadDefaultBip85ParentUsecase {
  final WalletRepository _walletRepository;
  final Preferences _preferences;

  const ReadDefaultBip85ParentUsecase(
    this._walletRepository,
    this._preferences,
  );

  Future<Result<Fingerprint, Bip85Failure>> execute() async {
    try {
      final settings = await _preferences.fetch();
      final Environment environment;
      switch (settings) {
        case Err(:final failure):
          return Err(
            Bip85UnexpectedFailure('preferences: ${failure.runtimeType}'),
          );
        case Ok(:final value):
          environment = value.environment;
      }
      switch (await _walletRepository.getWallets(
        onlyDefaults: true,
        onlyBitcoin: true,
        environment: environment,
      )) {
        case Err(:final failure):
          return Err(
            Bip85UnexpectedFailure('default wallet: ${failure.runtimeType}'),
          );
        case Ok(:final value):
          if (value.isEmpty) return const Err(Bip85NoDefaultWalletFailure());
          final storedFingerprint = value.first.masterFingerprint;
          final fingerprint = Fingerprint.tryParse(storedFingerprint);
          if (fingerprint == null || fingerprint.hex != storedFingerprint) {
            return const Err(
              Bip85UnexpectedFailure('invalid default wallet fingerprint'),
            );
          }
          return Ok(fingerprint);
      }
    } on Exception catch (failure) {
      return Err(
        Bip85UnexpectedFailure('default wallet: ${failure.runtimeType}'),
      );
    }
  }
}
