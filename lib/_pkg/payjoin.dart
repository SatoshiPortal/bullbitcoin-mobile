import 'package:payjoin_flutter/common.dart';
import 'package:payjoin_flutter/receive.dart';
import 'package:payjoin_flutter/uri.dart';

class PayJoin {
  static String directory = 'https://payjo.in';
  static String relay = 'https://pj.bobspacebkk.com';

  // from payjoin-flutter
  static Future<(Receiver, String)> initReceiver(
    BigInt sats,
    String address,
  ) async {
    final payjoinDirectory = await Url.fromStr(directory);
    final ohttpRelay = await Url.fromStr(relay);

    final ohttpKeys = await fetchOhttpKeys(
      ohttpRelay: ohttpRelay,
      payjoinDirectory: payjoinDirectory,
    );

    print('OHTTP KEYS FETCHED $ohttpKeys');

    // Create receiver session with new bindings
    final receiver = await Receiver.create(
      address: address,
      network: Network.signet,
      directory: payjoinDirectory,
      ohttpKeys: ohttpKeys,
      ohttpRelay: ohttpRelay,
      expireAfter: BigInt.from(60 * 5), // 5 minutes
    );

    print('INITIALIZED RECEIVER');

    final pjUrl = receiver.pjUriBuilder().amountSats(amount: sats).build();
    final pjStr = pjUrl.asString();

    print('PAYJOIN URL: $pjStr');

    return (receiver, pjStr);
  }
}
