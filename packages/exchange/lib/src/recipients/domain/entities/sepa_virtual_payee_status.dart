enum SepaVirtualPayeeStatus {
  absent,
  pending,
  active,

  /// A status this build doesn't know (e.g. a refused payee). Not read as
  /// pending, so nothing keeps polling or re-activating it.
  unknown;

  bool get exists => this != SepaVirtualPayeeStatus.absent;
  bool get isActive => this == SepaVirtualPayeeStatus.active;

  /// Whether activation can't move on by itself: active, or a status this
  /// build doesn't know.
  bool get isTerminal => switch (this) {
    SepaVirtualPayeeStatus.active || SepaVirtualPayeeStatus.unknown => true,
    SepaVirtualPayeeStatus.absent || SepaVirtualPayeeStatus.pending => false,
  };

  /// The payee status has no failed or rejected value this build knows of.
  bool get isFailed => false;
  bool get isRejected => false;
}
