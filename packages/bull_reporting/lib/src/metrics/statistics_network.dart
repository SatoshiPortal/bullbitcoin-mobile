/// Current active wallet network, supplied by the preferences owner.
abstract interface class StatisticsNetwork {
  /// False includes unknown or unreadable network state.
  Future<bool> isMainnet();

  /// True before a transition starts; false once all transitions finish.
  Stream<bool> get changes;
}
