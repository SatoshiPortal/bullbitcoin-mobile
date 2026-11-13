final class BullVaultTimeReference {
  static const maxChainTimeDifference = Duration(hours: 24);
  static const maxReviewAge = Duration(minutes: 15);
  static const _locktimeTimestampThreshold = 500000000;

  final DateTime deviceTime;
  final int chainHeight;
  final int medianTimePast;

  BullVaultTimeReference({
    required DateTime deviceTime,
    required this.chainHeight,
    required this.medianTimePast,
  }) : deviceTime = deviceTime.toUtc() {
    final deviceTimestamp = this.deviceTime.millisecondsSinceEpoch ~/ 1000;
    if (chainHeight <= 0 ||
        deviceTimestamp < _locktimeTimestampThreshold ||
        medianTimePast < _locktimeTimestampThreshold) {
      throw ArgumentError('BullVault requires a valid Bitcoin time reference');
    }
    final difference = (deviceTimestamp - medianTimePast).abs();
    if (difference > maxChainTimeDifference.inSeconds) {
      throw ArgumentError('Device time and Bitcoin chain time disagree');
    }
  }

  int get deviceTimestamp => deviceTime.millisecondsSinceEpoch ~/ 1000;

  bool isFreshComparedTo(BullVaultTimeReference current) {
    final age = current.deviceTime.difference(deviceTime);
    return !age.isNegative && age <= maxReviewAge;
  }
}
