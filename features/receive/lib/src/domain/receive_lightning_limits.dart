/// Boltz bounds constrain only the route that cannot fall back to Exchange.
final class ReceiveLightningLimits {
  const ReceiveLightningLimits({
    required this.requiresBounds,
    this.minimumSat,
    this.maximumSat,
  });
  final bool requiresBounds;
  final int? minimumSat;
  final int? maximumSat;

  bool get ready =>
      !requiresBounds || (minimumSat != null && maximumSat != null);
  bool below(int amountSat) =>
      requiresBounds &&
      switch (minimumSat) {
        final minimum? => amountSat < minimum,
        null => false,
      };
  bool above(int amountSat) =>
      requiresBounds &&
      switch (maximumSat) {
        final maximum? => amountSat > maximum,
        null => false,
      };
  bool permits(int amountSat) =>
      amountSat > 0 && ready && !below(amountSat) && !above(amountSat);
}
