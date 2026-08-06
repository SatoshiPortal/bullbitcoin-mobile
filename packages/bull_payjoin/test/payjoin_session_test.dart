import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

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

  test('does not offer receiver fallback after publishing a proposal', () {
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

    expect(session.canManuallyBroadcastOriginal, isFalse);
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
}
