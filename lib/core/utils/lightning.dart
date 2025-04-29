import 'package:boltz/boltz.dart';

Future<String> invoiceFromLnAddress({
  required String lnAddress,
  required int amountSat,
}) async {
  try {
    final lnurl = Lnurl(value: lnAddress);
    final invoice = await lnurl.fetchInvoice(
      msats: BigInt.from(amountSat * 1000),
    );
    return invoice;
  } catch (e) {
    rethrow;
  }
}
