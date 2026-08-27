import 'dart:convert';
import 'dart:typed_data';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_failure.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_invoice.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_signing.dart';
import 'package:bb_mobile/features/bullnym/domain/repositories/bullnym_repository.dart';
import 'package:bb_mobile/features/bullnym/domain/usecases/bullnym_usecases.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

const _presentationBytes = 1 + 12 + 4096 + 16;

void main() {
  test('accepts a canonical UUID v4 and private presentation envelope', () {
    expect(_fields().hasValidPrivatePresentation, isTrue);
  });

  test('rejects UUIDs the server would canonicalize before verification', () {
    expect(
      _fields(
        clientRequestId: '5E5F6F6A-6CAF-4F42-99B7-80F3212CD540',
      ).hasValidPrivatePresentation,
      isFalse,
    );
    expect(
      _fields(
        clientRequestId: '5e5f6f6a-6caf-3f42-99b7-80f3212cd540',
      ).hasValidPrivatePresentation,
      isFalse,
    );
  });

  test('rejects malformed or non-version-1 presentation envelopes', () {
    expect(
      _fields(presentationEnvelope: 'not-base64').hasValidPrivatePresentation,
      isFalse,
    );
    final wrongVersion = Uint8List(_presentationBytes);
    expect(
      _fields(
        presentationEnvelope: base64Url.encode(wrongVersion),
      ).hasValidPrivatePresentation,
      isFalse,
    );
  });

  test(
    'rejects invalid presentation fields before loading or signing',
    () async {
      final identity = _MockNostrIdentityFacade();
      final result = await CreateInvoiceUsecase(
        _MockBullnymRepository(),
        BullnymAuthenticator(identity),
      ).execute(nym: null, fields: _fields(presentationEnvelope: 'not-base64'));

      expect(result, isA<Err<BullnymCreateInvoiceResponse, BullnymFailure>>());
      verifyNever(identity.bullnymAuthPublicKey);
    },
  );
}

BullnymCreateInvoiceFields _fields({
  String clientRequestId = '5e5f6f6a-6caf-4f42-99b7-80f3212cd540',
  String? presentationEnvelope,
}) {
  final envelope = Uint8List(_presentationBytes)..[0] = 1;
  return BullnymCreateInvoiceFields(
    amountSat: 1000,
    clientRequestId: clientRequestId,
    presentationEnvelope: presentationEnvelope ?? base64Url.encode(envelope),
    acceptBtc: true,
    acceptLn: true,
    acceptLiquid: true,
  );
}

final class _MockNostrIdentityFacade extends Mock
    implements NostrIdentityFacade {}

final class _MockBullnymRepository extends Mock implements BullnymRepository {}
