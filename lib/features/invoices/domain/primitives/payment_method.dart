/// The rail a paid invoice settled over. Wire values mirror the server
/// `paid_via` strings (`bitcoin`, `lightning`, `liquid`).
enum PaymentMethod {
  btc,
  lightning,
  liquid;

  /// Tolerant reader: an unrecognized `paid_via` maps to null (the UI simply
  /// omits the rail line) rather than throwing.
  static PaymentMethod? fromWire(String? wire) {
    return switch (wire) {
      'bitcoin' => PaymentMethod.btc,
      'lightning' => PaymentMethod.lightning,
      'liquid' => PaymentMethod.liquid,
      _ => null,
    };
  }
}
