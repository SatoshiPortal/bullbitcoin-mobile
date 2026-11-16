import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/features/wallet/domain/default_wallet_failure.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/create_default_wallets_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/wallet_failure.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

export 'package:bb_mobile/features/wallet/domain/wallet.dart' show Wallet;
export 'package:bb_mobile/features/wallet/domain/default_wallet_failure.dart';

/// The default wallet operations available to other features.
final class DefaultWalletsFacade {
  final CreateDefaultWalletsUsecase _create;
  final GetWalletsUsecase _getWallets;

  const DefaultWalletsFacade(this._create, {required this._getWallets});

  /// Includes hidden wallets so restoration can preserve their existing labels.
  @useResult
  Future<Result<List<Wallet>, DefaultWalletFailure>> existingWallets() async =>
      switch (await _getWallets.execute(includeHidden: true)) {
        Ok(:final value) => Ok(value),
        Err(failure: NoWalletsFoundFailure()) => const Ok([]),
        Err() => const Err(DefaultWalletStorageFailure()),
      };

  @useResult
  Future<Result<List<Wallet>, DefaultWalletFailure>> create() =>
      _create.execute();

  @useResult
  Future<Result<List<Wallet>, DefaultWalletFailure>> restore({
    required List<String> words,
    String passphrase = '',
  }) => _create.execute(mnemonicWords: words, passphrase: passphrase);
}
