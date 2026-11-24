import 'package:bull_ark/bull_ark.dart';
import 'package:primitives/primitives.dart';
import 'package:receive/receive.dart';

import '../entities/internal_transfer.dart';

import 'package:swaps/order_swaps.dart';

import 'load_internal_ark_transfer_usecase.dart';

/// Navigation input, never a review or permission to sign.
final class InternalArkTransferHandoff {
  final String path;
  final Object entry;
  const InternalArkTransferHandoff(this.path, this.entry);
}

final class ReviewInternalArkTransferUsecase {
  final LoadInternalArkTransferUsecase _load;
  final Receive _receive;
  const ReviewInternalArkTransferUsecase(this._load, this._receive);

  Future<Result<InternalArkTransferHandoff, SwapFailure>> execute(
    InternalTransfer transfer,
  ) async {
    final failure = transfer.failure;
    final value = transfer.amount;
    if (failure != null) return Err(failure);
    if (value == null || !transfer.usesArk) {
      return const Err(SwapInvalidStateFailure());
    }
    final current = await _load.execute();
    if (current case Err(:final failure)) return Err(failure);
    if (current case Ok(:final value)) {
      if (value.config.id != transfer.ark.config.id ||
          value.boardSourceWalletId != transfer.ark.boardSourceWalletId ||
          value.config.arkUrl != transfer.ark.config.arkUrl ||
          value.config.primaryEsploraUrl !=
              transfer.ark.config.primaryEsploraUrl ||
          value.config.fallbackEsploraUrl !=
              transfer.ark.config.fallbackEsploraUrl ||
          value.snapshot.stale) {
        return const Err(SwapInvalidStateFailure());
      }
      final amount = transfer.amount;
      if (amount == null) return const Err(SwapValidationFailure());
      final minimum = transfer.isBoard
          ? value.snapshot.serverInfo?.minimumBoard?.value
          : null;
      if (minimum != null && amount < minimum) {
        return Err(
          SwapAmountOutOfBoundsFailure(
            limitAmountSat: minimum,
            isMinimum: true,
          ),
        );
      }
      if (transfer.from.kind == TransferWalletKind.ark) {
        final spendable = value.snapshot.spendable?.value;
        if (spendable == null) return const Err(SwapInvalidStateFailure());
        if (amount > spendable) {
          return Err(
            SwapAmountOutOfBoundsFailure(
              limitAmountSat: spendable,
              isMinimum: false,
            ),
          );
        }
      }
    }
    final amount = Sats(value);
    final account = transfer.ark.config.id;
    if (transfer.isBoard) {
      return Ok(
        InternalArkTransferHandoff(
          '/ark/board',
          ArkTransferBoardEntry(
            account: account,
            sourceWalletId: transfer.from.id,
            amount: amount,
          ),
        ),
      );
    }
    final address = await _receive.transferAddress(transfer.to.id);
    return switch (address) {
      Ok(:final value) when value.isNotEmpty && value.trim() == value => Ok(
        InternalArkTransferHandoff(
          '/ark/review',
          ArkTransferPaymentEntry(
            account: account,
            destination: value,
            amount: amount,
          ),
        ),
      ),
      _ => const Err(SwapProviderFailure()),
    };
  }
}
