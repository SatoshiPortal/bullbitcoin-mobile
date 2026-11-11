import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:primitives/primitives.dart';
import 'package:meta/meta.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/wallet/domain/liquid_send_port.dart';
import 'package:bb_mobile/features/send/domain/send_failure.dart';

class PrepareLiquidSendUsecase {
  final LiquidSendPort _liquidWalletRepository;

  PrepareLiquidSendUsecase({required this._liquidWalletRepository});

  @useResult
  Future<Result<String, SendFailure>> execute({
    required String walletId,
    required String address,
    required RelativeFee feeRate,
    int? amountSat,
    bool drain = false,
    Set<Outpoint>? selectedInputs,
    bool hasFrozenInputs = false,
  }) async {
    if (amountSat == null && !drain) {
      return const Err(SendTransactionBuildFailure('Amount required'));
    }
    final result = await _liquidWalletRepository.buildPset(
      walletId: walletId,
      address: address,
      amountSat: drain ? null : amountSat,
      feeRate: feeRate,
      drain: drain,
      selectedInputs: selectedInputs,
    );
    return result.mapErr(
      (failure) => switch (failure) {
        WalletSelectedInputsUnavailableFailure() =>
          const SendSelectedCoinsUnavailableFailure(),
        WalletNoSpendableInputsFailure() =>
          selectedInputs != null
              ? const SendSelectedCoinsUnavailableFailure()
              : const SendInsufficientBalanceFailure(),
        WalletInsufficientFundsFailure() =>
          selectedInputs != null
              ? const SendSelectedCoinsInsufficientFailure()
              : hasFrozenInputs
              ? const SendInsufficientBalanceFailure()
              : const SendInsufficientFundsForFeesFailure(),
        WalletConsolidationRequiredFailure() =>
          const SendConsolidationRequiredFailure(),
        _ => const SendTransactionBuildFailure(),
      },
    );
  }
}
