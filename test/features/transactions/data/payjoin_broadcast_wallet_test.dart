import '../../../scripted_wallet_connections.dart';

import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';
import 'package:sync/sync.dart'
    show
        SyncClosedFailure,
        SyncFailure,
        SyncNotFoundFailure,
        SyncStorageFailure,
        WalletKey;
import 'package:transactions/testing.dart';

void main() {
  test('a readable registration broadcasts from its wallet', () {
    final result = payjoinBroadcastWallet(
      Ok(
        walletRegistrationForTesting(
          id: 'wallet-1',
          network: BitcoinNetwork.testnet,
        ),
      ),
    );

    expect(
      result,
      isA<Ok<WalletKey, SyncFailure>>().having(
        (ok) => (ok.value.id, ok.value.network),
        'key',
        ('wallet-1', BitcoinNetwork.testnet),
      ),
    );
  });

  for (final (name, failure) in <(String, SecretFailure)>[
    ('a relocked inventory', const UseSecretFailure('inventory locked')),
    ('a changed inventory session', const UseSecretFailure('access changed')),
  ]) {
    test('$name closes the session before anything is sent', () async {
      final result = payjoinBroadcastWallet(Err(failure));
      expect(
        result,
        isA<Err<WalletKey, SyncFailure>>().having(
          (err) => err.failure,
          'failure',
          isA<SyncClosedFailure>(),
        ),
      );

      // The fallback reports it as never attempted, not as an unknown outcome.
      await expectLater(
        AppPayjoinBlockchainAdapter(
          ScriptedWalletConnections(),
          (
            walletId,
            transaction, {
            required network,
            built,
            owner,
            replacing,
          }) async => switch (result) {
            Ok() => fail('nothing may be broadcast'),
            Err(:final failure) => Err(failure),
          },
        ).broadcastPsbt(
          walletId: 'wallet-1',
          sessionId: 'session-1',
          network: BitcoinNetwork.testnet,
          psbt: 'psbt',
        ),
        throwsA(isA<PayjoinBroadcastNotAttemptedException>()),
      );
    });
  }

  test('a missing registration stays not found', () {
    expect(
      payjoinBroadcastWallet(const Err(WalletRegistrationNotFoundFailure())),
      isA<Err<WalletKey, SyncFailure>>().having(
        (err) => err.failure,
        'failure',
        isA<SyncNotFoundFailure>(),
      ),
    );
  });

  test('an unreadable registration stays a storage failure', () {
    expect(
      payjoinBroadcastWallet(const Err(UnreadableWalletFailure())),
      isA<Err<WalletKey, SyncFailure>>().having(
        (err) => err.failure,
        'failure',
        isA<SyncStorageFailure>(),
      ),
    );
  });
}
