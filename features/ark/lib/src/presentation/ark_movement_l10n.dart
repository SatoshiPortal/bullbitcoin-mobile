import 'package:ark/ark.dart';
import 'package:bull_ui/bull_ui.dart';

import 'ark_l10n.dart';

extension ArkMovementKindL10n on ArkMovementKind {
  String toTranslated(BuildContext context) {
    final l10n = arkLocalizationsOf(context);
    return switch (this) {
      ArkMovementKind.board => l10n.movementBoard,
      ArkMovementKind.payment => l10n.movementPayment,
      ArkMovementKind.renewal => l10n.movementRenewal,
      ArkMovementKind.exit => l10n.movementExit,
      ArkMovementKind.lightningReceive => l10n.movementLightningReceipt,
      ArkMovementKind.unknown => l10n.unknownState,
    };
  }
}

/// Source-reported status only; no independent chain or financial authority.
extension ArkMovementStatusL10n on ArkMovementStatus {
  String toTranslated(BuildContext context) {
    final l10n = arkLocalizationsOf(context);
    return switch (this) {
      ArkMovementStatus.pending => l10n.operationPending,
      ArkMovementStatus.successful => l10n.operationCompleted,
      ArkMovementStatus.failed => l10n.operationFailed,
      ArkMovementStatus.unknown => l10n.unknownState,
    };
  }
}
