import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/features/wallet/domain/default_wallet_failure.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/create_default_wallets_usecase.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' show Language;
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

export 'package:bb_mobile/features/wallet/domain/wallet.dart' show Wallet;
export 'package:bb_mobile/features/wallet/domain/default_wallet_failure.dart';

/// The default wallet operations available to other features.
final class DefaultWalletsFacade {
  final CreateDefaultWalletsUsecase _create;

  const DefaultWalletsFacade(this._create);

  @useResult
  Future<Result<List<Wallet>, DefaultWalletFailure>> create() =>
      _create.execute();

  @useResult
  Future<Result<List<Wallet>, DefaultWalletFailure>> restore({
    required List<String> words,
    required Language language,
    String passphrase = '',
  }) => _create.execute(
    mnemonicWords: words,
    language: language,
    passphrase: passphrase,
  );
}
