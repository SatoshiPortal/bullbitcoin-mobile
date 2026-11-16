/// Whether the device currently has a network, independent of Tor.
///
/// Arti reports "offline" when no relay answers; with a device network that
/// is the signature of a network blocking Tor, not of missing connectivity.
abstract interface class NetworkPresencePort {
  bool get hasNetwork;
}
