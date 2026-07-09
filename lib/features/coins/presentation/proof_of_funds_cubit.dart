import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/features/coins/domain/coins_error.dart';
import 'package:bb_mobile/features/coins/domain/usecases/sign_proof_of_funds_usecase.dart';
import 'package:bb_mobile/features/coins/presentation/proof_of_funds_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Drives the prove-funds flow (producing a proof over a wallet's selected
/// UTXOs). Verification lives in its own [VerifyProofOfFundsCubit] since it
/// needs no wallet. Thin: only calls the use-case and maps result/failure.
class ProofOfFundsCubit extends Cubit<ProofOfFundsState> {
  ProofOfFundsCubit({
    required String walletId,
    required this.network,
    required this.signProofOfFundsUsecase,
  }) : super(ProofOfFundsState(walletId: walletId));

  final Network network;
  final SignProofOfFundsUsecase signProofOfFundsUsecase;

  /// Produces a proof over [utxos] for [message]. Only Bitcoin UTXOs can be
  /// proven, so the caller passes an already-filtered [BitcoinWalletUtxo] list.
  Future<void> prove({
    required String message,
    required List<BitcoinWalletUtxo> utxos,
  }) async {
    emit(
      state.copyWith(
        status: ProofOfFundsStatus.working,
        error: null,
        signature: null,
      ),
    );
    try {
      final signature = await signProofOfFundsUsecase.execute(
        walletId: state.walletId,
        network: network,
        message: message,
        utxos: utxos,
      );
      emit(
        state.copyWith(
          status: ProofOfFundsStatus.success,
          signature: signature,
        ),
      );
    } on CoinsError catch (e) {
      emit(state.copyWith(status: ProofOfFundsStatus.error, error: e));
    } catch (e) {
      emit(
        state.copyWith(
          status: ProofOfFundsStatus.error,
          error: CoinsError.unexpected(message: e.toString()),
        ),
      );
    }
  }

  void clearError() => emit(state.copyWith(error: null));
}
