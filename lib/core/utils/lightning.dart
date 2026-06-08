import 'package:bull_sdk/boltz.dart' as boltz;

Future<String> invoiceFromLnAddress({
  required String lnAddress,
  required int amountSat,
}) async {
  try {
    final lnurl = boltz.Lnurl(value: lnAddress);
    final invoice = await lnurl.fetchInvoice(
      msats: BigInt.from(amountSat * 1000),
    );
    final decodedInvoice = await boltz.DecodedInvoice.fromString(s: invoice);
    final invoiceMsats = decodedInvoice.msats;
    final expectedMsats = BigInt.from(amountSat * 1000);
    if (invoiceMsats != expectedMsats) {
      throw Exception('LNURL invoice amount does not match requested amount');
    }
    return invoice.toLowerCase();
  } catch (e) {
    if (e is boltz.BoltzError) {
      throw Exception(e.message);
    }
    rethrow;
  }
}
