import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';
import 'package:sync/sync.dart';
import 'package:transactions/testing.dart';

class _Inventory extends Mock implements WalletInventory {}

void main() {
  final wallet = walletRegistrationForTesting(
    id: 'w1',
    network: BitcoinNetwork.mainnet,
  );
  late _Inventory inventory;
  late List<WalletKey> synchronized;
  late Result<void, SyncFailure> syncResult;
  late GetTransactionWalletUsecase usecase;

  setUp(() {
    inventory = _Inventory();
    synchronized = [];
    syncResult = const Ok(null);
    usecase = GetTransactionWalletUsecase(inventory, (key) async {
      synchronized.add(key);
      return syncResult;
    });
  });

  test('reads visible metadata without synchronizing by default', () async {
    when(() => inventory.readWallet('w1')).thenAnswer((_) async => Ok(wallet));
    expect(
      (await usecase.execute('w1')).fold((value) => value, (_) => null),
      wallet,
    );
    expect(synchronized, isEmpty);
  });

  test('keeps a missing registration distinct from storage failure', () async {
    when(
      () => inventory.readWallet('w1'),
    ).thenAnswer((_) async => const Err(WalletRegistrationNotFoundFailure()));
    expect(
      await usecase.execute('w1'),
      isA<Ok<WalletRegistration?, TransactionFailure>>(),
    );
    when(() => inventory.readWallet('w1'))
        .thenAnswer((_) async => const Err(UnreadableWalletFailure()));
    expect(
      await usecase.execute('w1'),
      isA<Err<WalletRegistration?, TransactionFailure>>(),
    );
  });

  test(
    'synchronizes the registered network and preserves sync failure',
    () async {
      when(() => inventory.readWallet('w1'))
          .thenAnswer((_) async => Ok(wallet));
      syncResult = const Err(SyncStorageFailure());
      expect(
        await usecase.execute('w1', sync: true),
        isA<Err<WalletRegistration?, TransactionFailure>>(),
      );
      expect(synchronized, [
        WalletKey(id: 'w1', network: BitcoinNetwork.mainnet),
      ]);
    },
  );
}
