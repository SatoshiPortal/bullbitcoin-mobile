import 'dart:convert';
import 'dart:typed_data';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_auth_signer.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_failure.dart';
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:meta/meta.dart';

// Deployed Bullnym wire domain. Renaming this is a breaking protocol change.
const String bullpayWireDomain = 'bullpay-la-v2';

const String bullpayActionRegister = 'register';
const String bullpayActionDelete = 'delete';
const String bullpayActionDonationPageSave = 'donation-page-save';
const String bullpayActionDonationPageArchive = 'donation-page-archive';

final _canonicalNpubHexPattern = RegExp(r'^[0-9a-f]{64}$');

// Optional-trailing signed-field rule (server `save_payload_fields` in
// `src/donation_page.rs`): the seven mandatory save fields (header, description,
// display_currency, website, twitter, instagram, enabled) are always present —
// absent optionals are signed as empty strings so the NUL-separator count is
// invariant. The trailing fields
// `[pos_mode?][ct_descriptor?][kind?][alias?]` are each appended only when the
// client sends that JSON key, and alias MUST stay last. This client never sends
// `pos_mode`, always sends a non-empty `ct_descriptor`, and always sends `kind`,
// so its preserve layout is the seven mandatory fields plus `ct_descriptor`
// then `kind`. A first alias claim appends the alias after `kind`; preserving an
// alias omits that newest field. Archive signs `[kind]` only.

@useResult
Result<Uint8List, BullnymFailure> buildBullpaySchnorrMessage({
  required String action,
  required String npubHex,
  required String nymOrEmpty,
  required List<String> payloadFields,
  required int timestampSecs,
}) {
  final builder = BytesBuilder();
  bool addField(String value) {
    if (value.contains('\u0000')) return false;
    builder.add(utf8.encode(value));
    builder.addByte(0);
    return true;
  }

  for (final field in [
    bullpayWireDomain,
    action,
    npubHex,
    nymOrEmpty,
    ...payloadFields,
  ]) {
    if (!addField(field)) {
      return const Err(
        BullnymFailure.invalidInput(
          'Bullnym signing fields must not contain null separators',
        ),
      );
    }
  }
  builder.add(utf8.encode(timestampSecs.toString()));
  return Ok(builder.toBytes());
}

@useResult
Future<Result<String, BullnymFailure>> signBullpayAction({
  required BullnymAuthSigner signer,
  required String action,
  required String nymOrEmpty,
  required List<String> payloadFields,
  required int timestampSecs,
}) async {
  switch (validateBullnymNpubHex(signer.npubHex)) {
    case Err(:final failure):
      return Err(failure);
    case Ok():
      break;
  }
  final messageResult = buildBullpaySchnorrMessage(
    action: action,
    npubHex: signer.npubHex,
    nymOrEmpty: nymOrEmpty,
    payloadFields: payloadFields,
    timestampSecs: timestampSecs,
  );
  final Uint8List message;
  switch (messageResult) {
    case Err(:final failure):
      return Err(failure);
    case Ok(:final value):
      message = value;
  }
  final digest = sha256.convert(message).bytes;
  try {
    return Ok(
      await Future<String>.value(signer.signHashHex(hex.encode(digest))),
    );
  } on Exception {
    // The callback may touch ephemeral key material; never retain its raw
    // exception text in a failure or log.
    return const Err(BullnymFailure.signingFailed());
  }
}

int currentBullpayTimestampSecs() {
  return DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
}

@useResult
Result<void, BullnymFailure> validateBullnymNpubHex(String npubHex) {
  if (_canonicalNpubHexPattern.hasMatch(npubHex)) return const Ok(null);
  return const Err(
    BullnymFailure.invalidInput(
      'Bullnym npub must be a 32-byte lowercase hex value',
    ),
  );
}
