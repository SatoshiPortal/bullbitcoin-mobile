import 'package:bb_mobile/_pkg/error.dart';
import 'package:bb_mobile/send/bloc/send_state.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
import 'package:boltz_dart/boltz_dart.dart' as boltz;
import 'package:lwk_dart/lwk_dart.dart' as lwk;
import 'package:payjoin_flutter/uri.dart' as pj_uri;

const lightningUri = 'lightning:';
const bitcoinUri = 'bitcoin:';
const liquidUris = [
  'liquidnetwork:',
  'liquidtestnet:',
];

Future<(AddressNetwork?, Err?)> checkIfValidLightningUri(
  String invoice,
) async {
  try {
    final _ = await boltz.DecodedInvoice.fromString(s: invoice);
    return (AddressNetwork.lightning, null);
  } catch (e) {
    return (null, Err('Invalid lightning invoice'));
  }
}

Future<(AddressNetwork?, Err?)> checkIfValidBip21LightningUri(
  String address,
) async {
  if (address.length > lightningUri.length) {
    final invoice = address.substring(lightningUri.length);
    final (_, err) = await checkIfValidLightningUri(invoice);

    if (err == null) {
      return (AddressNetwork.bip21Lightning, null);
    } else {
      return (null, Err('Invalid bip21 lightning invoice'));
    }
  } else {
    return (null, Err('Invalid bip21 lightning invoice'));
  }
}

Future<(AddressNetwork?, Err?)> checkIfValidBitcoinUri(
  String address,
  bdk.Network network,
) async {
  try {
    print("bitcoin: checkIfValidBitcoinUri $address");
    // bdk.Address vs bitcoinUri?
    // bdk.Address is just the pubkey, not the full uri (which is refered to as 'address' elsewhere)
    final _ = await bdk.Address.fromString(
      s: address,
      network: network,
    );
    return (AddressNetwork.bitcoin, null);
  } catch (e) {
    return (null, Err('Invalid bitcoin address'));
  }
}

Future<(AddressNetwork?, Err?)> checkIfValidBip21BitcoinUri(
  String address,
  bdk.Network network,
) async {
  print("bip21-bitcoin: checkIfValidBip21BitcoinUri $address");
  // this is manuall bip21 parsing logic that can be replaced with bitcoin.Uri.fromStr()
  try {
    final _ = pj_uri.Uri.fromStr(address);
    return (AddressNetwork.bip21Bitcoin, null);
  } catch (e) {
    return (null, Err('Invalid bip21 bitcoin uri'));
  }
}

Future<(AddressNetwork?, Err?)> checkIfValidLiquidUri(
  String address,
) async {
  try {
    final _ = await lwk.Address.validate(
      addressString: address,
    );
    return (AddressNetwork.liquid, null);
  } catch (e) {
    return (null, Err('Invalid liquid address'));
  }
}

Future<(AddressNetwork?, Err?)> checkIfValidBip21LiquidUri(
  String address,
) async {
  if (address.length > liquidUris[0].length) {
    // since both liquid uris are of same length
    final addr = address.substring(liquidUris[0].length).split('?').first;
    final (_, err) = await checkIfValidLiquidUri(addr);

    if (err == null) {
      return (AddressNetwork.bip21Liquid, null);
    } else {
      return (null, Err('Invalid bip21 liquid uri'));
    }
  } else {
    return (null, Err('Invalid bip21 liquid uri'));
  }
}
