import 'package:ark/funding.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:sync/sync.dart' show BitcoinSpendStatus;
import 'package:transactions/testing.dart';
import 'package:secrets/testing.dart' show unlockedSessionAuthority;

class _Metadata extends Mock implements WalletInventory {}

void main() {
  late _Metadata metadata;
  late int checks;

  PayjoinWalletAdapter adapter(BitcoinSpendStatus Function(int) status) =>
      PayjoinWalletAdapter(
        Secrets(
          authority: unlockedSessionAuthority(),
          scratchDirectory: () async => '/tmp',
        ),
        (_) async => throw StateError('no wallet handle expected'),
        (_) async => status(++checks),
        metadata,
        const ArkFundingSigningGuard(authority: null),
      );

  Future<void> utxos(PayjoinWalletAdapter adapter) => adapter.spendableUtxos(
    walletId: 'wallet',
    network: BitcoinNetwork.mainnet,
  );

  setUp(() {
    checks = 0;
    metadata = _Metadata();
    when(
      () => metadata.readWallet(any()),
    ).thenAnswer((_) async => const Err(WalletRegistrationNotFoundFailure()));
  });

  test('brief contention does not pause a proposal', () async {
    final wallet = adapter(
      (check) => check < 3 ? BitcoinSpendStatus.busy : BitcoinSpendStatus.ready,
    );
    // Admitted: the adapter went on to read the wallet.
    await expectLater(utxos(wallet), throwsStateError);
    expect(checks, 3);
    verify(() => metadata.readWallet('wallet')).called(1);
  });

  test('lasting contention pauses after a bounded wait', () async {
    final wallet = adapter((_) => BitcoinSpendStatus.busy);
    await expectLater(
      utxos(wallet),
      throwsA(
        isA<PayjoinSpendBlockedException>().having(
          (e) => e.busy,
          'busy',
          isTrue,
        ),
      ),
    );
    expect(checks, 5);
    verifyNever(() => metadata.readWallet(any()));
  });

  test('an unobserved payment pauses without retrying', () async {
    final wallet = adapter((_) => BitcoinSpendStatus.pending);
    await expectLater(
      utxos(wallet),
      throwsA(
        isA<PayjoinSpendBlockedException>().having(
          (e) => e.busy,
          'busy',
          isFalse,
        ),
      ),
    );
    expect(checks, 1);
  });
}
