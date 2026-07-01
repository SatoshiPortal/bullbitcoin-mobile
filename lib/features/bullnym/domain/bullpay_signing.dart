import 'dart:convert';
import 'dart:typed_data';

import 'package:bb_mobile/features/bullnym/domain/bullnym_auth_signer.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_error.dart';
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
    _throwIfContainsNull(value);
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

Future<String> signBullpayAction({
  required BullnymAuthSigner signer,
  required String action,
  required String nymOrEmpty,
  required List<String> payloadFields,
  required int timestampSecs,
}) async {
  final message = buildBullpaySchnorrMessage(
    action: action,
    npubHex: signer.npubHex,
    nymOrEmpty: nymOrEmpty,
    payloadFields: payloadFields,
    timestampSecs: timestampSecs,
  );
  final digest = sha256.convert(message).bytes;
  return Future<String>.value(signer.signHashHex(hex.encode(digest)));
}

int currentBullpayTimestampSecs() {
  return DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
}

void validateBullnymNpubHex(String npubHex) {
  try {
    final decoded = hex.decode(npubHex);
    if (decoded.length == 32) return;
  } on FormatException {
    // Throw the feature error below.
  }
  throw const BullnymException.invalidInput(
    'Bullnym npub must be a 32-byte hex value',
  );
}

void _throwIfContainsNull(String value) {
  if (value.contains('\u0000')) {
    throw const BullnymException.invalidInput(
      'Bullnym signing fields must not contain null separators',
    );
  }
}
