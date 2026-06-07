enum Bip85ReservationOwner { btcpay }

enum Bip85ReservationPurpose { walletSeed }

class Bip85ApplicationSpec {
  final int number;

  const Bip85ApplicationSpec({required this.number});
}

class Bip85PathSegment {
  final String name;
  final int value;

  const Bip85PathSegment({required this.name, required this.value});
}

class Bip85ReservationScope {
  final int applicationNumber;
  final List<Bip85PathSegment> segments;
  final int walletIndex;

  Bip85ReservationScope._({
    required this.applicationNumber,
    required List<Bip85PathSegment> segments,
  }) : segments = List.unmodifiable(segments),
       walletIndex = _requiredSegmentValue(segments, 'index');

  String get exactPath =>
      "$applicationNumber'/${segments.map((segment) => "${segment.value}'").join('/')}";

  bool matchesExactPath(String path) => exactPath == path;

  int segmentValue(String name) {
    for (final segment in segments) {
      if (segment.name == name) return segment.value;
    }
    throw StateError('Unknown BIP85 reservation path segment: $name');
  }

  static int _requiredSegmentValue(
    List<Bip85PathSegment> segments,
    String name,
  ) {
    for (final segment in segments) {
      if (segment.name == name) return segment.value;
    }
    throw ArgumentError(
      "BIP85 reservation scope requires an '$name' path segment",
    );
  }
}

class Bip85Reservation {
  final String id;
  final String deterministicAlias;
  final Bip85ReservationOwner owner;
  final Bip85ReservationPurpose purpose;
  final Bip85ApplicationSpec application;
  final Bip85ReservationScope scope;

  Bip85Reservation({
    required this.id,
    required this.deterministicAlias,
    required this.owner,
    required this.purpose,
    required this.application,
    required List<Bip85PathSegment> segments,
  }) : scope = Bip85ReservationScope._(
         applicationNumber: application.number,
         segments: segments,
       );

  int get walletIndex => scope.walletIndex;
}
