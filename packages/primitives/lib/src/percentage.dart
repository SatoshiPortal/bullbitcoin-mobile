double calculatePercentage(num amount, num fee) {
  if (amount == 0) return 0.0;
  final percent = (fee / amount) * 100;
  return double.parse(percent.toStringAsFixed(2));
}
