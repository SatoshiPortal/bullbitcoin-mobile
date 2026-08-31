enum BullVaultProtection { standard, extra }

extension BullVaultProtectionX on BullVaultProtection {
  bool get usesTwoColdKeys => this == BullVaultProtection.extra;
}
