enum BullnymPayerQuoteRail {
  lightning('lightning'),
  liquid('liquid'),
  bitcoin('bitcoin');

  final String wire;

  const BullnymPayerQuoteRail(this.wire);

  static BullnymPayerQuoteRail? fromWire(String value) => switch (value) {
    'lightning' => lightning,
    'liquid' => liquid,
    'bitcoin' => bitcoin,
    _ => null,
  };
}

class BullnymPayerQuoteRailAvailability {
  final bool lightning;
  final bool liquid;
  final bool bitcoin;

  const BullnymPayerQuoteRailAvailability({
    required this.lightning,
    required this.liquid,
    required this.bitcoin,
  });
}

class BullnymFiatQuote {
  final String quoteVersionId;
  final int versionNumber;
  final int fiatFaceAmountMinor;
  final int fiatTargetAmountMinor;
  final String fiatCurrency;
  final int rateMinorPerBtc;
  final String rateSource;
  final int rateObservedAtUnix;
  final int rateFetchedAtUnix;
  final int rateFreshUntilUnix;
  final int merchantAmountSat;
  final int createdAtUnix;
  final int expiresAtUnix;

  const BullnymFiatQuote({
    required this.quoteVersionId,
    required this.versionNumber,
    required this.fiatFaceAmountMinor,
    required this.fiatTargetAmountMinor,
    required this.fiatCurrency,
    required this.rateMinorPerBtc,
    required this.rateSource,
    required this.rateObservedAtUnix,
    required this.rateFetchedAtUnix,
    required this.rateFreshUntilUnix,
    required this.merchantAmountSat,
    required this.createdAtUnix,
    required this.expiresAtUnix,
  });
}

sealed class BullnymVersionedPayerInstruction {
  final int payerAmountSat;

  const BullnymVersionedPayerInstruction({required this.payerAmountSat});
}

final class BullnymLightningQuoteInstruction
    extends BullnymVersionedPayerInstruction {
  final String quoteOfferId;
  final String pr;

  const BullnymLightningQuoteInstruction({
    required this.quoteOfferId,
    required this.pr,
    required super.payerAmountSat,
  });
}

final class BullnymLiquidQuoteInstruction
    extends BullnymVersionedPayerInstruction {
  final String address;

  const BullnymLiquidQuoteInstruction({
    required this.address,
    required super.payerAmountSat,
  });
}

final class BullnymBitcoinDirectQuoteInstruction
    extends BullnymVersionedPayerInstruction {
  final String address;
  final String bip21;

  const BullnymBitcoinDirectQuoteInstruction({
    required this.address,
    required this.bip21,
    required super.payerAmountSat,
  });
}

final class BullnymBitcoinBoltzQuoteInstruction
    extends BullnymVersionedPayerInstruction {
  final String quoteOfferId;
  final String address;
  final String bip21;

  const BullnymBitcoinBoltzQuoteInstruction({
    required this.quoteOfferId,
    required this.address,
    required this.bip21,
    required super.payerAmountSat,
  });
}

class BullnymPayerDemandQuoteResponse {
  final String invoiceId;
  final BullnymPayerQuoteRail selectedRail;
  final BullnymFiatQuote quote;
  final BullnymVersionedPayerInstruction instruction;

  const BullnymPayerDemandQuoteResponse({
    required this.invoiceId,
    required this.selectedRail,
    required this.quote,
    required this.instruction,
  });
}
