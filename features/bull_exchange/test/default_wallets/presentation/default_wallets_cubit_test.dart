import 'dart:async';

import 'package:bull_exchange/src/default_wallets/domain/validate_default_wallet_destination_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:bull_exchange/src/default_wallets/domain/default_wallets_failure.dart';
import 'package:bull_exchange/src/default_wallets/presentation/default_wallets_cubit.dart';
import 'package:bull_exchange/src/default_wallets/presentation/default_wallets_state.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class MockValidateDestination extends Mock
    implements ValidateDefaultWalletDestinationUsecase {}

void main() {
  late MockValidateDestination validateDestination;
  late Exchange exchange;
  late int saveCalls;

  DefaultWalletsCubit buildCubit() => DefaultWalletsCubit(
    validateDestination: validateDestination,
    exchange: exchange,
  );

  setUp(() {
    validateDestination = MockValidateDestination();
    saveCalls = 0;
    exchange = exchangeForTesting(
      saveDefaultWallet:
          ({required walletType, required address, existingRecipientId}) async {
            saveCalls++;
            return const WriteRefused(ExchangeRefusal(rpcCode: -32603));
          },
    );
  });

  const savedWallets = DefaultWallets(
    bitcoin: DefaultWallet(
      walletType: BtcNetwork.bitcoin,
      address: 'bc1qaddress',
    ),
    liquid: DefaultWallet(walletType: BtcNetwork.liquid, address: 'lq1address'),
  );

  blocTest<DefaultWalletsCubit, DefaultWalletsState>(
    'loads the saved wallet addresses',
    setUp: () {
      exchange = exchangeForTesting(
        getDefaultWallets: () async => const Ok(savedWallets),
      );
    },
    build: buildCubit,
    act: (cubit) => cubit.init(),
    expect: () => const [
      DefaultWalletsState(isLoading: true),
      DefaultWalletsState(
        defaultWallets: savedWallets,
        bitcoinAddressInput: 'bc1qaddress',
        liquidAddressInput: 'lq1address',
      ),
    ],
  );

  blocTest<DefaultWalletsCubit, DefaultWalletsState>(
    'restores saved values when editing is cancelled',
    build: buildCubit,
    seed: () => const DefaultWalletsState(
      defaultWallets: DefaultWallets(
        bitcoin: DefaultWallet(
          walletType: BtcNetwork.bitcoin,
          address: 'bc1qsaved',
        ),
      ),
      bitcoinAddressInput: 'bc1qsaved',
    ),
    act: (cubit) {
      cubit.startEditing(BtcNetwork.bitcoin);
      cubit.updateBitcoinAddress('bc1qchanged');
      cubit.cancelEditing();
    },
    expect: () => const [
      DefaultWalletsState(
        defaultWallets: DefaultWallets(
          bitcoin: DefaultWallet(
            walletType: BtcNetwork.bitcoin,
            address: 'bc1qsaved',
          ),
        ),
        editingWalletType: BtcNetwork.bitcoin,
        bitcoinAddressInput: 'bc1qsaved',
      ),
      DefaultWalletsState(
        defaultWallets: DefaultWallets(
          bitcoin: DefaultWallet(
            walletType: BtcNetwork.bitcoin,
            address: 'bc1qsaved',
          ),
        ),
        editingWalletType: BtcNetwork.bitcoin,
        bitcoinAddressInput: 'bc1qchanged',
      ),
      DefaultWalletsState(
        defaultWallets: DefaultWallets(
          bitcoin: DefaultWallet(
            walletType: BtcNetwork.bitcoin,
            address: 'bc1qsaved',
          ),
        ),
        bitcoinAddressInput: 'bc1qsaved',
      ),
    ],
  );

  blocTest<DefaultWalletsCubit, DefaultWalletsState>(
    'rejects an empty address without calling the save use case',
    build: buildCubit,
    act: (cubit) => cubit.saveWallet(BtcNetwork.bitcoin),
    expect: () => const [
      DefaultWalletsState(saveError: DefaultWalletsEmptyAddressFailure()),
    ],
    verify: (_) {
      expect(saveCalls, 0);
    },
  );

  test(
    'rejects a destination from the wrong payment rail before saving',
    () async {
      when(
        () =>
            validateDestination.execute(BtcNetwork.bitcoin, 'user@example.com'),
      ).thenAnswer((_) async => null);
      final cubit = buildCubit();
      cubit.startEditing(BtcNetwork.bitcoin);
      cubit.updateBitcoinAddress('user@example.com');
      await cubit.saveWallet(BtcNetwork.bitcoin);
      expect(cubit.state.saveError, isA<DefaultWalletsInvalidAddressFailure>());
      expect(cubit.state.isSaving, isFalse);
      expect(saveCalls, 0);
      await cubit.close();
    },
  );

  test(
    'does not save a validation result after the destination changes',
    () async {
      final pending = Completer<String?>();
      when(() => validateDestination.execute(BtcNetwork.bitcoin, 'old'))
          .thenAnswer((_) => pending.future);
      final cubit = buildCubit();
      cubit.updateBitcoinAddress('old');
      final saving = cubit.saveWallet(BtcNetwork.bitcoin);
      cubit.updateBitcoinAddress('new');
      pending.complete('normalized-old');
      await saving;
      expect(cubit.state.bitcoinAddressInput, 'new');
      expect(cubit.state.isSaving, isFalse);
      expect(saveCalls, 0);
      await cubit.close();
    },
  );
  test('cancelling editing invalidates a pending validation', () async {
    final pending = Completer<String?>();
    when(() => validateDestination.execute(BtcNetwork.bitcoin, 'old'))
        .thenAnswer((_) => pending.future);
    final cubit = buildCubit();
    cubit.startEditing(BtcNetwork.bitcoin);
    cubit.updateBitcoinAddress('old');
    final saving = cubit.saveWallet(BtcNetwork.bitcoin);
    cubit.cancelEditing();
    pending.complete('normalized-old');
    await saving;
    expect(cubit.state.editingWalletType, isNull);
    expect(cubit.state.isSaving, isFalse);
    expect(saveCalls, 0);
    await cubit.close();
  });

  test('an unknown save outcome re-reads the default wallets, so the next '
      'save updates the recipient it may have created', () async {
    const created = DefaultWallets(
      bitcoin: DefaultWallet(
        recipientId: 'r-1',
        walletType: BtcNetwork.bitcoin,
        address: 'bc1qnew',
      ),
    );
    var reads = 0;
    final saves = <String?>[];
    exchange = exchangeForTesting(
      getDefaultWallets: () async =>
          Ok(reads++ == 0 ? const DefaultWallets() : created),
      saveDefaultWallet:
          ({required walletType, required address, existingRecipientId}) async {
            saves.add(existingRecipientId);
            return const WriteOutcomeUnknown('receive timeout');
          },
    );
    when(() => validateDestination.execute(BtcNetwork.bitcoin, 'bc1qnew'))
        .thenAnswer((_) async => 'bc1qnew');
    final cubit = buildCubit();
    await cubit.init();
    cubit.startEditing(BtcNetwork.bitcoin);
    cubit.updateBitcoinAddress('bc1qnew');

    await cubit.saveWallet(BtcNetwork.bitcoin);

    expect(
      cubit.state.saveError,
      isA<DefaultWalletsSaveOutcomeUnknownFailure>(),
    );
    expect(cubit.state.isSaving, isFalse);
    expect(cubit.state.defaultWallets, created);

    await cubit.saveWallet(BtcNetwork.bitcoin);
    expect(saves, [null, 'r-1']);
    await cubit.close();
  });
}
