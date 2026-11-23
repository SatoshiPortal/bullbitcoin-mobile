import 'package:primitives/primitives.dart';
import 'package:silent/src/domain/entities/sp_address.dart';
import 'package:silent/src/domain/entities/sp_recipient.dart';
import 'package:rust_bindings/bwk.dart' as bwk;

/// Maps between the domain [SilentRecipient] and the bwk FFI `RecipientView`.
abstract final class SpRecipientMapper {
  static bwk.RecipientView toFfi(SilentRecipient recipient) =>
      switch (recipient) {
        SilentRecipientSp(
          :final address,
          :final amountSat,
          :final label,
          :final isMax,
        ) =>
          bwk.RecipientView.sp(
            address: address.value,
            amountSat: amountSat.value,
            label: label,
            isMax: isMax,
          ),
        SilentRecipientStandard(
          :final address,
          :final amountSat,
          :final isMax,
        ) =>
          bwk.RecipientView.standard(
            address: address.value,
            amountSat: amountSat.value,
            isMax: isMax,
          ),
      };

  static SilentRecipient toDomain(bwk.RecipientView view) => switch (view) {
    bwk.RecipientView_Sp(
      :final address,
      :final amountSat,
      :final label,
      :final isMax,
    ) =>
      SilentRecipientSp(
        address: SilentAddress(address),
        amountSat: Sats(amountSat),
        label: label,
        isMax: isMax,
      ),
    bwk.RecipientView_Standard(
      :final address,
      :final amountSat,
      :final isMax,
    ) =>
      SilentRecipientStandard(
        address: SilentAddress(address),
        amountSat: Sats(amountSat),
        isMax: isMax,
      ),
  };
}
