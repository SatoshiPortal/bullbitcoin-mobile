import 'dart:convert';
import 'dart:typed_data';

import 'package:bb_mobile/core/nostr/nostr_keychain_handle.dart';
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';

// Deployed Bullnym wire domain. Renaming this is a breaking protocol change.
const String bullpayWireDomain = 'bullpay-la-v2';

const String bullpayActionRegister = 'register';
const String bullpayActionDelete = 'delete';

Uint8List buildBullpaySchnorrMessage({
  required String action,
  required String npubHex,
  required String nymOrEmpty,
  required List<String> payloadFields,
  required int timestampSecs,
}) {
  final builder = BytesBuilder();
  void addField(String value) {
    builder.add(utf8.encode(value));
    builder.addByte(0);
  }

  addField(bullpayWireDomain);
  addField(action);
  addField(npubHex);
  addField(nymOrEmpty);
  for (final field in payloadFields) {
    addField(field);
  }
  builder.add(utf8.encode(timestampSecs.toString()));
  return builder.toBytes();
}

String signBullpayAction({
  required NostrKeychainHandle handle,
  required String action,
  required String nymOrEmpty,
  required List<String> payloadFields,
  required int timestampSecs,
}) {
  final message = buildBullpaySchnorrMessage(
    action: action,
    npubHex: handle.publicKeyHex,
    nymOrEmpty: nymOrEmpty,
    payloadFields: payloadFields,
    timestampSecs: timestampSecs,
  );
  final digest = sha256.convert(message).bytes;
  return handle.signHashHex(hex.encode(digest));
}

int currentBullpayTimestampSecs() {
  return DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
}
