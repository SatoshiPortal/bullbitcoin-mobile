import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/wallet/domain/default_wallet_failure.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/create_default_wallets_usecase.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

export 'package:bb_mobile/core/wallet/domain/entities/wallet.dart' show Wallet;
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
    String passphrase = '',
  }) => _create.execute(mnemonicWords: words, passphrase: passphrase);
}
