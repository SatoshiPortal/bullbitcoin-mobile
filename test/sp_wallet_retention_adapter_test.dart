import 'package:bb_mobile/core/wallet/domain/wallet_mutation_guard.dart';
import 'package:bb_mobile/features/sp/public/sp_facade.dart';
import 'package:bb_mobile/sp_wallet_retention_adapter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _SpFacade extends Mock implements SpFacade {}

void main() {
  final secretId = Fingerprint('00112233');

  test(
    'background destruction is refused without resolving the SP owner',
    () async {
      var resolutions = 0;
      final policy = SpWalletRetentionAdapter(
        facade: () {
          resolutions++;
          throw StateError('owner unavailable');
        },
        allowDestructiveOperations: false,
      );
      expect(await policy.retainsWallet('wallet'), isTrue);
      expect(await policy.retainsSecret(secretId), isTrue);
      expect(resolutions, 0);
    },
  );

  test(
    'foreground checks the owner while the shared mutation guard is held',
    () async {
      final facade = _SpFacade();
      final guard = WalletMutationGuard();
      final calls = <String>[];
      when(() => facade.retainsSource(walletId: 'wallet')).thenAnswer((
        _,
      ) async {
        calls.add('retention');
        return const Ok(false);
      });
      final policy = SpWalletRetentionAdapter(
        facade: () => facade,
        allowDestructiveOperations: true,
      );
      await guard.exclusive(() async {
        expect(await policy.retainsWallet('wallet'), isFalse);
        calls.add('mutation');
      });
      expect(calls, ['retention', 'mutation']);
    },
  );

  test('a retained secret cannot be treated as unreferenced', () async {
    final facade = _SpFacade();
    when(
      () => facade.retainsSource(secretId: secretId),
    ).thenAnswer((_) async => const Ok(true));
    final policy = SpWalletRetentionAdapter(
      facade: () => facade,
      allowDestructiveOperations: true,
    );
    expect(await policy.retainsSecret(secretId), isTrue);
  });

  test(
    'an unreadable owner refuses destruction with fixed diagnostics',
    () async {
      final facade = _SpFacade();
      when(() => facade.retainsSource(walletId: 'wallet')).thenAnswer(
        (_) async => const Err(SpUnexpected('untrusted identity metadata')),
      );
      final policy = SpWalletRetentionAdapter(
        facade: () => facade,
        allowDestructiveOperations: true,
      );
      await expectLater(
        policy.retainsWallet('wallet'),
        throwsA(
          isA<WalletRetentionCheckFailed>().having(
            (error) => error.toString(),
            'fixed message',
            'Wallet retention cannot be verified',
          ),
        ),
      );
    },
  );

  test('a missing foreground owner has no permissive fallback', () async {
    final policy = SpWalletRetentionAdapter(
      facade: () => throw StateError('not registered'),
      allowDestructiveOperations: true,
    );
    await expectLater(
      policy.retainsWallet('wallet'),
      throwsA(isA<WalletRetentionCheckFailed>()),
    );
  });
}
