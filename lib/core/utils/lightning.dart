import 'package:boltz/boltz.dart';

Future<String> invoiceFromLnAddress({
  required String lnAddress,
  required int amountSat,
}) async {
  try {
    final invoice = await invoiceFromLnurl(
      lnurl: lnAddress,
      msats: BigInt.from(amountSat * 1000),
    );
    return invoice;
  } catch (e) {
    rethrow;
  }
}
