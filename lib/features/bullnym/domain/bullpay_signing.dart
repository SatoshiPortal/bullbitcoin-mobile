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
const String bullpayActionDonationPageSave = 'donation-page-save';
const String bullpayActionDonationPageArchive = 'donation-page-archive';

// Optional-trailing signed-field rule (server `save_payload_fields` in
// `src/donation_page.rs`): the seven mandatory save fields (header, description,
// display_currency, website, twitter, instagram, enabled) are always present —
// absent optionals are signed as empty strings so the NUL-separator count is
// invariant. The trailing fields `[pos_mode?][ct_descriptor?][kind?]` are each
// appended only when the client sends that JSON key, and `kind` MUST stay last.
// This client never sends `pos_mode`, always sends a non-empty `ct_descriptor`,
// and always sends `kind`, so its save layout is the seven mandatory fields plus
// `ct_descriptor` then `kind`. Archive signs `[kind]` only.

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
  if (RegExp(r'^[0-9a-f]{64}$').hasMatch(npubHex)) return;
  throw const BullnymException.invalidInput(
    'Bullnym npub must be a 32-byte lowercase hex value',
  );
}

void _throwIfContainsNull(String value) {
  if (value.contains('\u0000')) {
    throw const BullnymException.invalidInput(
      'Bullnym signing fields must not contain null separators',
    );
  }
}
