import 'package:bb_mobile/core/electrum/domain/ports/electrum_servers_port.dart';
import 'package:bb_mobile/core/electrum/domain/ports/environment_port.dart';
import 'package:bb_mobile/core/electrum/domain/repositories/electrum_transaction_repository.dart';
import 'package:bb_mobile/core/electrum/frameworks/drift/datasources/electrum_remote_datasource.dart';
import 'package:bb_mobile/core/wallet/data/repositories/bitcoin_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_utxos_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_utxo_repository.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_finished_wallet_syncs_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_started_wallet_syncs_usecase.dart';
import 'package:bb_mobile/features/coins/domain/usecases/freeze_utxos_usecase.dart';
import 'package:bb_mobile/features/coins/domain/usecases/get_utxos_usecase.dart';
import 'package:bb_mobile/features/coins/domain/usecases/sign_proof_of_funds_usecase.dart';
import 'package:bb_mobile/features/coins/domain/usecases/unfreeze_utxos_usecase.dart';
import 'package:bb_mobile/features/coins/domain/usecases/verify_proof_of_funds_usecase.dart';
import 'package:bb_mobile/features/coins/presentation/coins_cubit.dart';
import 'package:bb_mobile/features/coins/presentation/proof_of_funds_cubit.dart';
import 'package:bb_mobile/features/coins/presentation/verify_proof_of_funds_cubit.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:get_it/get_it.dart';

class CoinsLocator {
  static void setup(GetIt locator) {
    // Feature usecases (thin wrappers over the shared core wallet layer).
    locator.registerFactory<GetUtxosUsecase>(
      () => GetUtxosUsecase(
        getWalletUtxosUsecase: locator<GetWalletUtxosUsecase>(),
      ),
    );
    locator.registerFactory<FreezeUtxosUsecase>(
      () => FreezeUtxosUsecase(
        walletUtxoRepository: locator<WalletUtxoRepository>(),
      ),
    );
    locator.registerFactory<UnfreezeUtxosUsecase>(
      () => UnfreezeUtxosUsecase(
        walletUtxoRepository: locator<WalletUtxoRepository>(),
      ),
    );

    // Proof-of-funds usecases (BIP-322).
    locator.registerFactory<SignProofOfFundsUsecase>(
      () => SignProofOfFundsUsecase(
        walletRepository: locator<BitcoinWalletRepository>(),
      ),
    );
    locator.registerFactory<VerifyProofOfFundsUsecase>(
      () => VerifyProofOfFundsUsecase(
        serversPort: locator<ElectrumServersPort>(),
        transactionRepository: locator<ElectrumTransactionRepository>(),
        electrumDatasource: locator<ElectrumRemoteDatasource>(),
        environmentPort: locator<EnvironmentPort>(),
      ),
    );

    // Cubit — built per route with the target wallet id.
    locator.registerFactoryParam<CoinsCubit, String, void>(
      (walletId, _) => CoinsCubit(
        walletId: walletId,
        getUtxosUsecase: locator<GetUtxosUsecase>(),
        freezeUtxosUsecase: locator<FreezeUtxosUsecase>(),
        unfreezeUtxosUsecase: locator<UnfreezeUtxosUsecase>(),
        labelsFacade: locator<LabelsFacade>(),
        watchStartedWalletSyncsUsecase:
            locator<WatchStartedWalletSyncsUsecase>(),
        watchFinishedWalletSyncsUsecase:
            locator<WatchFinishedWalletSyncsUsecase>(),
      ),
    );

    // Prove-funds cubit — built per route with the target wallet
    // (id + network needed to derive per-UTXO keys and sign).
    locator.registerFactoryParam<ProofOfFundsCubit, Wallet, void>(
      (wallet, _) => ProofOfFundsCubit(
        walletId: wallet.id,
        network: wallet.network,
        signProofOfFundsUsecase: locator<SignProofOfFundsUsecase>(),
      ),
    );

    // Verify-funds cubit — standalone (no wallet needed); network is resolved
    // from the app environment inside the use-case. Used from Settings.
    locator.registerFactory<VerifyProofOfFundsCubit>(
      () => VerifyProofOfFundsCubit(
        verifyProofOfFundsUsecase: locator<VerifyProofOfFundsUsecase>(),
      ),
    );
  }
}
