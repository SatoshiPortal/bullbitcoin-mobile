enum SepaVirtualPayeeStatus {
  absent,
  pending,
  active;

  bool get exists => this != SepaVirtualPayeeStatus.absent;
  bool get isActive => this == SepaVirtualPayeeStatus.active;
}
