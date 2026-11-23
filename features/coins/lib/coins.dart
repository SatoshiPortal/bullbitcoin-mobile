/// Wallet coin reads and user freeze operations.
library;

import 'package:labels/labels.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:sync/sync.dart';

import 'src/data/wallet_utxo_repository_impl.dart';
import 'src/domain/coins_failure.dart';
import 'src/domain/wallet_utxo.dart';
import 'src/domain/wallet_utxo_repository.dart';

export 'src/coin_selection_sheet.dart'
    show CoinSelectionEntry, CoinSelectionLabels, CoinSelectionSheet;
export 'src/domain/coins_failure.dart';
export 'src/domain/wallet_utxo.dart';

typedef CoinSummary = ({int count, BigInt frozenSat});

abstract interface class Coins {
  static Coins open({
    required WalletInventory inventory,
    required Labels labels,
    required Future<Result<Wallet, SyncFailure>> Function(WalletKey) loadWallet,
    required CoinFreezes freezes,
  }) => _Coins(
    WalletUtxoRepositoryImpl(
      inventory: inventory,
      labelsFacade: labels,
      loadWallet: loadWallet,
      freezesDatasource: freezes,
    ),
  );

  @useResult
  Future<Result<List<WalletUtxo>, CoinsFailure>> coins(String walletId);

  @useResult
  Future<Result<CoinSummary, CoinsFailure>> summary(String walletId);

  @useResult
  Future<Result<void, CoinsFailure>> freeze(
    String walletId,
    List<Outpoint> outpoints,
  );

  @useResult
  Future<Result<void, CoinsFailure>> unfreeze(List<Outpoint> outpoints);
}

final class _Coins implements Coins {
  final WalletUtxoRepository _repository;

  const _Coins(this._repository);

  @override
  Future<Result<List<WalletUtxo>, CoinsFailure>> coins(String walletId) =>
      _repository.coins(walletId);

  @override
  Future<Result<CoinSummary, CoinsFailure>> summary(String walletId) async =>
      (await coins(walletId)).map(
        (utxos) => (
          count: utxos.length,
          frozenSat: utxos
              .where((utxo) => utxo.isFrozen)
              .fold(BigInt.zero, (sum, utxo) => sum + utxo.amountSat),
        ),
      );

  @override
  Future<Result<void, CoinsFailure>> freeze(
    String walletId,
    List<Outpoint> outpoints,
  ) => _repository.freeze(walletId, outpoints);

  @override
  Future<Result<void, CoinsFailure>> unfreeze(List<Outpoint> outpoints) =>
      _repository.unfreeze(outpoints);
}
