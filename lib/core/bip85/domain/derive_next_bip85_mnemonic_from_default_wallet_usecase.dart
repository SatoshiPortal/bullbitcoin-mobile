import 'package:bb_mobile/core/bip85/data/bip85_repository.dart';
import 'package:bb_mobile/core/bip85/domain/bip85_derivation_entity.dart';
import 'package:bb_mobile/core/bip85/domain/errors/bip85_failure.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:meta/meta.dart';

class DeriveNextBip85MnemonicFromDefaultWalletUsecase {
  final Bip85Repository _bip85Repository;
  final GetDefaultSeedUsecase _getDefaultSeed;
  final GetSettingsUsecase _getSettings;

  DeriveNextBip85MnemonicFromDefaultWalletUsecase({
    required this._bip85Repository,
    required GetDefaultSeedUsecase getDefaultSeedUsecase,
    required GetSettingsUsecase getSettingsUsecase,
  }) : _getDefaultSeed = getDefaultSeedUsecase,
       _getSettings = getSettingsUsecase;

  @useResult
  Future<Result<({String derivation, bip39.Mnemonic mnemonic}), Bip85Failure>>
  execute({
    bip39.MnemonicLength length = bip39.MnemonicLength.words12,
    String? alias,
    Set<int> excludedIndices = const {},
  }) async {
    try {
      final settings = await _getSettings.execute();
      final seedResult = await _getDefaultSeed.execute(
        environment: settings.environment,
      );
      final Seed defaultSeed;
      switch (seedResult) {
        case Ok(:final value):
          defaultSeed = value;
        case Err(:final failure):
          return Err(bip85FailureFromDefaultSeed(failure));
      }

      final xprv = Bip32Derivation.getCanonicalRootXprvFromSeed(
        defaultSeed.bytes,
      );

      const application = Bip85Application.bip39;
      final indexResult = await _bip85Repository.fetchNextIndexForApplication(
        application,
        excludedIndices: excludedIndices,
      );
      switch (indexResult) {
        case Err(:final failure):
          return Err(failure);
        case Ok(:final value):
          return _bip85Repository.deriveMnemonic(
            xprvBase58: xprv,
            length: length,
            index: value,
            alias: alias,
          );
      }
    } on Exception catch (e, st) {
      log.severe(
        message: 'DeriveNextBip85MnemonicFromDefaultWalletUsecase failed',
        error: e.runtimeType,
        trace: st,
      );
      return const Err(
        Bip85UnexpectedFailure('BIP85 next-mnemonic derivation failed'),
      );
    }
  }
}
