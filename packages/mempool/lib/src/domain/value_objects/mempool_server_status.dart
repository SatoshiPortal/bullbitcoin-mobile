enum MempoolServerStatus {
  online,
  offline,
  checking,
  unknown;

  bool get isOnline => this == MempoolServerStatus.online;
  bool get isOffline => this == MempoolServerStatus.offline;
  bool get isChecking => this == MempoolServerStatus.checking;
  bool get isUnknown => this == MempoolServerStatus.unknown;
}
