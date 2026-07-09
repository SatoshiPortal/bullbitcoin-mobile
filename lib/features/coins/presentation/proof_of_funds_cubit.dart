import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/features/coins/domain/coins_error.dart';
import 'package:bb_mobile/features/coins/domain/usecases/sign_proof_of_funds_usecase.dart';
import 'package:bb_mobile/features/coins/domain/usecases/verify_proof_of_funds_usecase.dart';
import 'package:bb_mobile/features/coins/presentation/proof_of_funds_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Drives the prove-funds and verify-funds flows. Thin: it only calls the two
/// use-cases and maps their result/failure into state.
class ProofOfFundsCubit extends Cubit<ProofOfFundsState> {
  ProofOfFundsCubit({
    required String walletId,
    required this.network,
    required this.signProofOfFundsUsecase,
    required this.verifyProofOfFundsUsecase,
  }) : super(ProofOfFundsState(walletId: walletId));

  final Network network;
  final SignProofOfFundsUsecase signProofOfFundsUsecase;
  final VerifyProofOfFundsUsecase verifyProofOfFundsUsecase;

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

  /// Verifies a pasted/scanned proof [signature] for [message] and
  /// [challengeAddress], including the on-chain UTXO check.
  Future<void> verify({
    required String message,
    required String challengeAddress,
    required String signature,
  }) async {
    emit(
      state.copyWith(
        status: ProofOfFundsStatus.working,
        error: null,
        result: null,
      ),
    );
    try {
      final result = await verifyProofOfFundsUsecase.execute(
        message: message,
        challengeAddress: challengeAddress,
        signature: signature,
        network: network,
      );
      emit(state.copyWith(status: ProofOfFundsStatus.success, result: result));
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
