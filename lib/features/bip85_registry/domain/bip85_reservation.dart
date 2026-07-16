enum Bip85ReservationOwner {
  btcpay,
  lightningAddress,
  paymentPage,
  nostr,
  keychainManifest,
}

enum Bip85ReservationPurpose {
  walletSeed,
  nonWalletNostrKey,
  manifestEncryptionKey,
}

class Bip85ApplicationSpec {
  final int number;

  const Bip85ApplicationSpec({required this.number});
}

class Bip85PathSegment {
  final String name;
  final int value;

  const Bip85PathSegment({required this.name, required this.value});
}

/// The reserved derivation shape of a registry entry.
///
/// Wallet-seed reservations always carry a hardened `index` segment and expose
/// it as a typed [Bip85WalletSeedReservationScope.walletIndex]. Key
/// reservations are identified by their full segment shape and never carry an
/// `index` segment, so a key reservation cannot even be asked for a wallet
/// index. Both shapes derive [exactPath] from the application number and the
/// ordered segments; the path is never stored separately.
sealed class Bip85ReservationScope {
  final int applicationNumber;
  final List<Bip85PathSegment> segments;

  Bip85ReservationScope._({
    required this.applicationNumber,
    required List<Bip85PathSegment> segments,
  }) : segments = List.unmodifiable(segments);

  String get exactPath =>
      "$applicationNumber'/${segments.map((segment) => "${segment.value}'").join('/')}";

  bool matchesExactPath(String path) => exactPath == path;

  int segmentValue(String name) {
    for (final segment in segments) {
      if (segment.name == name) return segment.value;
    }
    throw StateError('Unknown BIP85 reservation path segment: $name');
  }
}

final class Bip85WalletSeedReservationScope extends Bip85ReservationScope {
  final int walletIndex;

  Bip85WalletSeedReservationScope._({
    required super.applicationNumber,
    required super.segments,
  }) : walletIndex = _requiredSegmentValue(segments, 'index'),
       super._();

  static int _requiredSegmentValue(
    List<Bip85PathSegment> segments,
    String name,
  ) {
    for (final segment in segments) {
      if (segment.name == name) return segment.value;
    }
    throw ArgumentError(
      "BIP85 wallet seed reservation scope requires an '$name' path segment",
    );
  }
}

final class Bip85KeyReservationScope extends Bip85ReservationScope {
  Bip85KeyReservationScope._({
    required super.applicationNumber,
    required super.segments,
  }) : super._() {
    // Strict by construction: an `index` segment on a key reservation would
    // signal a mis-shaped wallet-seed entry, so it is rejected eagerly rather
    // than silently ignored.
    for (final segment in segments) {
      if (segment.name == 'index') {
        throw ArgumentError(
          "BIP85 key reservation scopes must not carry an 'index' segment",
        );
      }
    }
  }
}

sealed class Bip85Reservation {
  final String id;
  final String deterministicAlias;
  final Bip85ReservationOwner owner;
  final Bip85ReservationPurpose purpose;
  final Bip85ApplicationSpec application;

  Bip85ReservationScope get scope;

  Bip85Reservation._({
    required this.id,
    required this.deterministicAlias,
    required this.owner,
    required this.purpose,
    required this.application,
  });
}

/// A reservation that materializes a BIP85 child wallet seed at a required
/// hardened `index` segment.
final class Bip85WalletSeedReservation extends Bip85Reservation {
  @override
  final Bip85WalletSeedReservationScope scope;

  Bip85WalletSeedReservation({
    required super.id,
    required super.deterministicAlias,
    required super.owner,
    required super.application,
    required List<Bip85PathSegment> segments,
  }) : scope = Bip85WalletSeedReservationScope._(
         applicationNumber: application.number,
         segments: segments,
       ),
       super._(purpose: Bip85ReservationPurpose.walletSeed);

  int get walletIndex => scope.walletIndex;
}

/// A reservation for non-wallet key material. Key reservations have no wallet
/// index; their reserved path is fully described by the application number and
/// role segments.
final class Bip85KeyReservation extends Bip85Reservation {
  @override
  final Bip85KeyReservationScope scope;

  Bip85KeyReservation({
    required super.id,
    required super.deterministicAlias,
    required super.owner,
    required super.purpose,
    required super.application,
    required List<Bip85PathSegment> segments,
  }) : scope = Bip85KeyReservationScope._(
         applicationNumber: application.number,
         segments: segments,
       ),
       super._() {
    if (purpose == Bip85ReservationPurpose.walletSeed) {
      throw ArgumentError(
        'wallet seed reservations must be modeled as Bip85WalletSeedReservation',
      );
    }
  }
}
