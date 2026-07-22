import 'package:bb_mobile/features/sp/domain/entities/sp_recipient.dart';
import 'package:bull_sdk/bwk.dart' as bwk;

/// Maps between the domain [SpRecipient] and the bwk FFI `RecipientView`.
abstract final class SpRecipientMapper {
  static bwk.RecipientView toFfi(SpRecipient recipient) => switch (recipient) {
    SpRecipientSp(
      :final address,
      :final amountSat,
      :final label,
      :final isMax,
    ) =>
      bwk.RecipientView.sp(
        address: address,
        amountSat: amountSat,
        label: label,
        isMax: isMax,
      ),
    SpRecipientStandard(:final address, :final amountSat, :final isMax) =>
      bwk.RecipientView.standard(
        address: address,
        amountSat: amountSat,
        isMax: isMax,
      ),
  };

  static SpRecipient toDomain(bwk.RecipientView view) => switch (view) {
    bwk.RecipientView_Sp(
      :final address,
      :final amountSat,
      :final label,
      :final isMax,
    ) =>
      SpRecipientSp(
        address: address,
        amountSat: amountSat,
        label: label,
        isMax: isMax,
      ),
    bwk.RecipientView_Standard(
      :final address,
      :final amountSat,
      :final isMax,
    ) =>
      SpRecipientStandard(address: address, amountSat: amountSat, isMax: isMax),
  };
}
