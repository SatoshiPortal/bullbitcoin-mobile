import 'package:flutter_test/flutter_test.dart';
import 'package:labels/labels.dart';
import 'package:mocktail/mocktail.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';
import 'package:sync/sync.dart';
import 'package:transactions/testing.dart';

class _Inventory extends Mock implements WalletInventory {}

class _Labels extends Mock implements Labels {}

class _Values extends Mock implements WalletHistoryDatasource {}

void main() {
  final readable = walletRegistrationForTesting(
    id: 'readable',
    network: BitcoinNetwork.testnet,
  );

  setUpAll(
    () => registerFallbackValue(
      WalletKey(id: 'readable', network: BitcoinNetwork.testnet),
    ),
  );

  late _Inventory metadata;
  late _Values bdk;
  late List<WalletKey> synchronized;
  late WalletTransactionRepositoryImpl repository;

  setUp(() {
    metadata = _Inventory();
    bdk = _Values();
    synchronized = [];
    when(
      () => bdk.getTransactions(
        key: any(named: 'key'),
        toAddress: any(named: 'toAddress'),
      ),
    ).thenAnswer((_) async => const Ok([]));
    final labels = _Labels();
    when(() => labels.fetch(reference: any(named: 'reference')))
        .thenAnswer((_) async => const Ok(<Label>[]));
    repository = WalletTransactionRepositoryImpl(
      inventory: metadata,
      labelsFacade: labels,
      history: bdk,
      synchronize: (key) async {
        synchronized.add(key);
        return const Ok(null);
      },
    );
  });

  test('an unreadable network row does not hide the other wallets', () async {
    when(() => metadata.walletsForNetwork(BitcoinNetwork.testnet))
        .thenAnswer((_) async => Ok(walletSelectionForTesting([readable])));
    when(() => metadata.walletsForNetwork(LiquidNetwork.testnet))
        .thenAnswer((_) async => const Err(UnreadableWalletFailure()));

    expect(
      (await repository.getWalletTransactions(
        environment: Environment.testnet,
        sync: true,
      )).fold(
        (value) => value,
        (failure) => fail(failure.runtimeType.toString()),
      ),
      isEmpty,
    );

    final read = verify(
      () => bdk.getTransactions(
        key: captureAny(named: 'key'),
        toAddress: any(named: 'toAddress'),
      ),
    ).captured;
    expect(read.map((wallet) => (wallet as WalletKey).id), ['readable']);
    expect(synchronized.map((row) => row.id), ['readable']);
  });

  test(
    'a loaded transaction is returned, not lost to an untyped list',
    () async {
      when(() => metadata.walletsForNetwork(BitcoinNetwork.testnet))
          .thenAnswer((_) async => Ok(walletSelectionForTesting([readable])));
      when(() => metadata.walletsForNetwork(LiquidNetwork.testnet))
          .thenAnswer((_) async => const Err(UnreadableWalletFailure()));
      when(
        () => bdk.getTransactions(
          key: any(named: 'key'),
          toAddress: any(named: 'toAddress'),
        ),
      ).thenAnswer(
        (_) async => const Ok([
          WalletTransactionModel(
            txId: 'public-transaction',
            isIncoming: true,
            amountSat: 1000,
            feeSat: 0,
            vsize: 100,
            inputs: [],
            outputs: [],
            network: BitcoinNetwork.testnet,
            isRbf: false,
          ),
        ]),
      );

      final loaded = await repository.getWalletTransactions(
        environment: Environment.testnet,
        sync: false,
      );
      expect(
        loaded
            .fold(
              (value) => value,
              (failure) => fail(failure.runtimeType.toString()),
            )
            .map((tx) => tx.txId),
        ['public-transaction'],
      );
    },
  );

  test('a wallet asked for by id with an unreadable network fails', () async {
    when(() => metadata.readWallet('unreadable'))
        .thenAnswer((_) async => const Err(UnreadableWalletFailure()));

    final result = await repository.getWalletTransactions(
      walletId: 'unreadable',
    );
    expect(
      result.fold((_) => null, (failure) => failure),
      isA<TransactionAggregationFailure>(),
    );
    verifyNever(
      () => bdk.getTransactions(
        key: any(named: 'key'),
        toAddress: any(named: 'toAddress'),
      ),
    );
  });
}
