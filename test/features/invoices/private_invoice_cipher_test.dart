import 'dart:convert';
import 'dart:io';

import 'package:bb_mobile/features/invoices/data/models/private_invoice_presentation_model.dart';
import 'package:bb_mobile/features/invoices/data/private_invoice_cipher_impl.dart';
import 'package:bb_mobile/features/invoices/domain/entities/private_invoice_presentation.dart';
import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('private invoice fixture', () {
    test('matches the canonical Bullnym v1 envelope byte for byte', () async {
      final fixture =
          jsonDecode(
                File(
                  'test/fixtures/private_invoice_v1.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final cipher = PrivateInvoiceCipherImpl(
        randomBytes: (length) => switch (length) {
          3634 => List<int>.filled(length, 0),
          32 => List<int>.generate(length, (index) => index),
          12 => List<int>.generate(length, (index) => 0xa0 + index),
          16 => List<int>.filled(length, 0xf0),
          _ => throw StateError('unexpected random request: $length'),
        },
      );

      final encrypted = await cipher.encrypt(_fixturePresentation());

      expect(encrypted.viewingKey, fixture['view_key_base64url']);
      expect(
        encrypted.presentationEnvelope,
        fixture['presentation_envelope_base64url'],
      );
      expect(encrypted.presentationEnvelope.length, 5500);

      final envelope = base64Url.decode(encrypted.presentationEnvelope);
      expect(envelope.length, fixture['presentation_envelope_length']);
      expect(
        sha256.convert(envelope).toString(),
        fixture['presentation_envelope_sha256'],
      );
      expect(envelope.first, 1);

      final nonce = envelope.sublist(1, 13);
      final cleartext = await AesGcm.with256bits().decrypt(
        SecretBox(
          envelope.sublist(13, envelope.length - 16),
          nonce: nonce,
          mac: Mac(envelope.sublist(envelope.length - 16)),
        ),
        secretKey: SecretKey(List<int>.generate(32, (index) => index)),
        aad: utf8.encode('bullnym-private-invoice-presentation-v1'),
      );
      expect(cleartext.length, 4096);
      expect(
        sha256.convert(cleartext).toString(),
        fixture['padded_plaintext_sha256'],
      );
      final jsonLength = (cleartext[0] << 8) | cleartext[1];
      expect(jsonLength, fixture['presentation_json_utf8_length']);
      expect(
        jsonDecode(utf8.decode(cleartext.sublist(2, 2 + jsonLength))),
        fixture['presentation'],
      );
      expect(cleartext.sublist(2 + jsonLength), everyElement(0));
    });

    test('production encryption is fixed-size and randomized', () async {
      final cipher = PrivateInvoiceCipherImpl();
      final presentation = PrivateInvoicePresentation();
      final first = await cipher.encrypt(presentation);
      final second = await cipher.encrypt(presentation);

      expect(first.presentationEnvelope.length, 5500);
      expect(second.presentationEnvelope.length, 5500);
      expect(first.viewingKey.length, 43);
      expect(second.viewingKey.length, 43);
      expect(first.presentationEnvelope, isNot(second.presentationEnvelope));
      expect(first.viewingKey, isNot(second.viewingKey));
      expect(first.clientRequestId, isNot(second.clientRequestId));
    });
  });

  group('private invoice presentation', () {
    test('trims values and omits empty fields and sections', () {
      final presentation = PrivateInvoicePresentation(
        payer: PrivateInvoiceContact(name: ' Jane ', email: '   '),
        invoice: PrivateInvoiceDetails(description: '  Work  '),
        payee: PrivateInvoiceContact(),
      );

      expect(PrivateInvoicePresentationModel.fromEntity(presentation).value, {
        'schema': 'bullnym-private-invoice',
        'version': 1,
        'payer': {'name': 'Jane'},
        'invoice': {'description': 'Work'},
      });
    });

    test('validates Gregorian date-only values', () {
      expect(
        () => PrivateInvoiceDetails(invoiceDate: '2024-02-29'),
        returnsNormally,
      );
      expect(
        () => PrivateInvoiceDetails(invoiceDate: '2025-02-29'),
        throwsA(isA<PrivateInvoicePresentationException>()),
      );
      expect(
        () => PrivateInvoiceDetails(paymentDeadline: '2026-7-18'),
        throwsA(isA<PrivateInvoicePresentationException>()),
      );
    });

    test('enforces UTF-8 byte limits and rejects control characters', () {
      expect(() => PrivateInvoiceContact(name: 'é' * 60), returnsNormally);
      expect(
        () => PrivateInvoiceContact(name: 'é' * 61),
        throwsA(isA<PrivateInvoicePresentationException>()),
      );
      expect(
        () => PrivateInvoiceContact(email: 'a\u0000b@example.com'),
        throwsA(isA<PrivateInvoicePresentationException>()),
      );
      expect(
        () => PrivateInvoiceContact(address: 'line one\nline two'),
        returnsNormally,
      );
    });
  });
}

PrivateInvoicePresentation _fixturePresentation() {
  return PrivateInvoicePresentation(
    payer: PrivateInvoiceContact(
      name: 'Jane Smith',
      corporateName: 'Example Corporation',
      address: '123 Main Street\nMontréal, QC',
      email: 'jane@example.com',
      phone: '+1 514 555 0100',
    ),
    invoice: PrivateInvoiceDetails(
      description: 'Website design services',
      number: 'INV-2026-0042',
      purchaseOrderReference: 'PO-9182',
      invoiceDate: '2026-07-18',
      paymentDeadline: '2026-08-18',
    ),
    payee: PrivateInvoiceContact(
      name: 'John Merchant',
      corporateName: 'Merchant Studio Inc.',
    ),
  );
}
