import 'dart:typed_data';

import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:bull_payjoin/src/engine/bitcoin_tx.dart';
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

TxInput _input(String txid, [int vout = 0]) => TxInput(txid: txid, vout: vout);

TxOutput _output(int script, [int value = 1000]) =>
    TxOutput(value: value, scriptPubkey: Uint8List.fromList([script]));

void main() {
  final createdAt = DateTime.utc(2026, 7, 30);

  test('hashes a sender URI before exposing its log reference', () {
    final session = PayjoinSenderSession(
      status: PayjoinStatus.requested,
      uri: 'bitcoin:bc1qsecret?amount=1&pj=https://relay.example',
      network: BitcoinNetwork.mainnet,
      walletId: 'wallet',
      createdAt: createdAt,
      expiresAt: createdAt.add(const Duration(hours: 1)),
      amount: Sats.fromInt(100000000),
      originalTransactionId: 'original',
    );

    expect(session.logRef, hasLength(16));
    expect(session.logRef, isNot(contains('bitcoin')));
  });

  test('keeps an opaque receiver ID as its log reference', () {
    final session = PayjoinReceiverSession(
      status: PayjoinStatus.requested,
      id: '0123456789abcdef',
      network: BitcoinNetwork.mainnet,
      walletId: 'wallet',
      createdAt: createdAt,
      expiresAt: createdAt.add(const Duration(hours: 1)),
      payjoinUri: 'bitcoin:address',
      hasOriginalTransaction: true,
    );

    expect(session.logRef, session.id);
    expect(session.canManuallyBroadcastOriginal, isTrue);
  });

  test('offers receiver fallback after publishing a proposal', () {
    final session = PayjoinReceiverSession(
      status: PayjoinStatus.proposed,
      id: '0123456789abcdef',
      network: BitcoinNetwork.mainnet,
      walletId: 'wallet',
      createdAt: createdAt,
      expiresAt: createdAt.add(const Duration(hours: 1)),
      payjoinUri: 'bitcoin:address',
      hasOriginalTransaction: true,
      hasProposal: true,
    );

    expect(session.canManuallyBroadcastOriginal, isTrue);
  });

  test('keeps sender fallback available after proposal expiry', () {
    final session = PayjoinSenderSession(
      status: PayjoinStatus.expired,
      uri: 'bitcoin:address?pj=https://example.com',
      network: BitcoinNetwork.mainnet,
      walletId: 'wallet',
      createdAt: createdAt,
      expiresAt: createdAt.add(const Duration(hours: 1)),
      amount: Sats.fromInt(10000),
      originalTransactionId: 'original',
      hasProposal: true,
    );

    expect(session.canManuallyBroadcastOriginal, isTrue);
  });

  test('does not offer fallback after it is marked aborted', () {
    final session = PayjoinSenderSession(
      status: PayjoinStatus.aborted,
      uri: 'bitcoin:address?pj=https://example.com',
      network: BitcoinNetwork.mainnet,
      walletId: 'wallet',
      createdAt: createdAt,
      expiresAt: createdAt.add(const Duration(hours: 1)),
      amount: Sats.fromInt(10000),
      originalTransactionId: 'original',
    );

    expect(session.canManuallyBroadcastOriginal, isFalse);
  });

  test('rejects an invalid session window', () {
    expect(
      () => PayjoinReceiverSession(
        status: PayjoinStatus.started,
        id: '0123456789abcdef',
        network: BitcoinNetwork.mainnet,
        walletId: 'wallet',
        createdAt: createdAt,
        expiresAt: createdAt,
        payjoinUri: 'bitcoin:address',
      ),
      throwsArgumentError,
    );
  });

  test('derives both parties from the original and proposal', () {
    final paymentScript = paymentScriptFromBip21(
      'bitcoin:bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq?amount=0.0005',
      isTestnet: false,
    );
    expect(paymentScript, isNotNull);

    final original = BitcoinTx(
      txid: 'original',
      inputs: [_input('a'), _input('b', 1)],
      outputs: [
        TxOutput(value: 50000, scriptPubkey: paymentScript!),
        _output(2, 40000),
      ],
    );
    final proposal = BitcoinTx(
      txid: 'proposal',
      inputs: [_input('receiver'), _input('a'), _input('b', 1)],
      outputs: [_output(3, 49000), _output(2, 39500), _output(4, 500)],
    );

    final ownership = derivePayjoinOwnership(
      original: original,
      proposal: proposal,
      paymentScript: paymentScript,
    );

    expect(ownership?.inputs, [
      PayjoinParty.recipient,
      PayjoinParty.sender,
      PayjoinParty.sender,
    ]);
    expect(ownership?.outputs, [
      PayjoinParty.recipient,
      PayjoinParty.sender,
      PayjoinParty.recipient,
    ]);
  });

  test('does not guess when the comparison is ambiguous', () {
    final original = BitcoinTx(
      txid: 'original',
      inputs: [_input('sender')],
      outputs: [_output(1, 50000), _output(2, 40000)],
    );
    final paymentScript = Uint8List.fromList([1]);

    for (final proposal in [
      BitcoinTx(
        txid: 'no receiver input',
        inputs: original.inputs,
        outputs: original.outputs,
      ),
      BitcoinTx(
        txid: 'ambiguous sender output',
        inputs: [_input('sender'), _input('receiver')],
        outputs: [_output(2, 39500), _output(2, 500)],
      ),
    ]) {
      expect(
        derivePayjoinOwnership(
          original: original,
          proposal: proposal,
          paymentScript: paymentScript,
        ),
        isNull,
        reason: proposal.txid,
      );
    }
  });
}
