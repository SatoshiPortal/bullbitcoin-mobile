enum SepaVirtualPayeeStatus {
  absent,
  created,
  processing,
  active,
  unknown;

  bool get isActive => this == SepaVirtualPayeeStatus.active;
  bool get isProcessing => exists && !isActive;
  bool get exists => switch (this) {
    SepaVirtualPayeeStatus.created ||
    SepaVirtualPayeeStatus.processing ||
    SepaVirtualPayeeStatus.active => true,
    SepaVirtualPayeeStatus.absent || SepaVirtualPayeeStatus.unknown => false,
  };
}
