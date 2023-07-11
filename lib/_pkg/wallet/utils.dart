import 'dart:convert';
import 'dart:math';

import 'package:bb_mobile/_model/wallet.dart';
import 'package:bitcoin_utils/xyzpub.dart';

String fingerPrintFromDescr(
  String xkey, {
  required bool isTesnet,
  bool ignorePrefix = false,
}) {
  final startIndex = xkey.indexOf('[');
  if (startIndex == -1) return '';
  final fingerPrintEndIndex = xkey.indexOf('/');
  var fingerPrint = xkey.substring(startIndex + 1, fingerPrintEndIndex);
  if (isTesnet && !ignorePrefix) fingerPrint = 'tn::' + fingerPrint;
  return fingerPrint;
}

String keyFromDescr(String descriptor) {
  final startIndex = descriptor.indexOf(']');
  final cut1 = descriptor.substring(startIndex + 1);
  final endIndex = cut1.indexOf('/');
  return cut1.substring(0, endIndex);
}

String convertToXpubStr(String xpub) {
  if (xpub.toLowerCase().startsWith('u') || xpub.toLowerCase().startsWith('v')) {
    final result = convertVersion(xpub, Version.tPub);
    return result;
  }
  if (xpub.toLowerCase().startsWith('y') || xpub.toLowerCase().startsWith('z')) {
    final result = convertVersion(xpub, Version.xPub);
    return result;
  }

  return xpub;
}

String keyFromPrivDescr(String descriptor) {
  final startIndex = descriptor.indexOf('(');
  final cut1 = descriptor.substring(startIndex + 1);
  final endIndex = cut1.indexOf('/');
  return cut1.substring(0, endIndex);
}

String buildDescriptorVanilla({
  required String xpub,
  required WalletType walletType,
  required bool isChange,
}) {
  try {
    final change = isChange ? '1' : '0';
    final endPath = '/$change/*';
    String descriptor = '';

    switch (walletType) {
      case WalletType.bip84:
        descriptor = 'wpkh($xpub$endPath)';
      case WalletType.bip49:
        descriptor = 'sh(wpkh($xpub$endPath))';
      case WalletType.bip44:
        descriptor = 'pkh($xpub$endPath)';
    }

    return descriptor;
  } catch (e) {
    // return (null, Err(e.toString()));
    rethrow;
  }
}

String splitCombinedChanged(String descriptor, bool isChange) {
  var str = descriptor;

  if (descriptor.contains('<')) {
    final startIndex = descriptor.indexOf('<');
    final endIndex = descriptor.indexOf('>');
    final cut1 = descriptor.substring(0, startIndex);
    final cut2 = descriptor.substring(endIndex + 1);
    final change = isChange ? '1' : '0';
    str = cut1 + change + cut2;
  }

  return str;
}

String generateFingerPrint(int len) {
  final random = Random.secure();
  final values = List<int>.generate(len, (i) => random.nextInt(255));
  return base64UrlEncode(values);
}


// wpkh(tprv8ZgxMBicQKsPcthqtyCtGtGzJhWXNC5QwGek1GQMs9vxHFrqhfXzdL5tstUWjLfm8JNeY7TvG2PxrfY5F8edd1JLyXqb2e86JhG4icehVAy/84'/1'/0'/1/*)#7420nc5y
// pkh([ddffda99/44'/1'/0']tpubDC5phKKvZNyMBySbRhQW6t1AkutpvxpAbPacFw38eM2DpiMRZAUBXooGNaBUzVKsST56w1osYwEuRtmqsEpKw4fw8mYWm3jbsjMGnYrgbUz/0/*)#23krdrn4
// pkh([258ee68c/44'/1'/0']tpubDGkapRgaKKcdaEtBkHfcWBDsrUWh1Lubu7JWEyPdU3LTkJQmxMz6qKzWVcAuSNyWjRe7kJ9EVzk6BosPSP5GvfR6SuB913zP1jqUxsjBUsQ/0/*)#75nf0v7a
// pkh([ddffda99/44'/1'/0']tpubDC5phKKvZNyMBySbRhQW6t1AkutpvxpAbPacFw38eM2DpiMRZAUBXooGNaBUzVKsST56w1osYwEuRtmqsEpKw4fw8mYWm3jbsjMGnYrgbUz/0/*)#23krdrn4
// pkh([ddffda99/44'/1'/0']tpubDC5phKKvZNyMBySbRhQW6t1AkutpvxpAbPacFw38eM2DpiMRZAUBXooGNaBUzVKsST56w1osYwEuRtmqsEpKw4fw8mYWm3jbsjMGnYrgbUz/0/*)#23krdrn4
// pkh([ddffda99/44'/1'/0']tpubDC5phKKvZNyMBySbRhQW6t1AkutpvxpAbPacFw38eM2DpiMRZAUBXooGNaBUzVKsST56w1osYwEuRtmqsEpKw4fw8mYWm3jbsjMGnYrgbUz/0/*)#23krdrn4
// pkh([ddffda99/44'/1'/0']tpubDC5phKKvZNyMBySbRhQW6t1AkutpvxpAbPacFw38eM2DpiMRZAUBXooGNaBUzVKsST56w1osYwEuRtmqsEpKw4fw8mYWm3jbsjMGnYrgbUz/0/*)#23krdrn4
// pkh([ddffda99/44'/1'/0']tpubDC5phKKvZNyMBySbRhQW6t1AkutpvxpAbPacFw38eM2DpiMRZAUBXooGNaBUzVKsST56w1osYwEuRtmqsEpKw4fw8mYWm3jbsjMGnYrgbUz/0/*)#23krdrn4
