import 'dart:async';

import 'package:bb_mobile/features/default_wallets/domain/validate_default_wallet_destination_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:bb_mobile/features/default_wallets/domain/default_wallets_failure.dart';
import 'package:bb_mobile/features/default_wallets/presentation/default_wallets_cubit.dart';
import 'package:bb_mobile/features/default_wallets/presentation/default_wallets_state.dart';
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
            return const Err(ExchangeUnexpectedFailure());
          },
    );
  });

  const savedWallets = DefaultWallets(
    bitcoin: DefaultWallet(
      walletType: WalletAddressType.bitcoin,
      address: 'bc1qaddress',
    ),
    liquid: DefaultWallet(
      walletType: WalletAddressType.liquid,
      address: 'lq1address',
    ),
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
          walletType: WalletAddressType.bitcoin,
          address: 'bc1qsaved',
        ),
      ),
      bitcoinAddressInput: 'bc1qsaved',
    ),
    act: (cubit) {
      cubit.startEditing(WalletAddressType.bitcoin);
      cubit.updateBitcoinAddress('bc1qchanged');
      cubit.cancelEditing();
    },
    expect: () => const [
      DefaultWalletsState(
        defaultWallets: DefaultWallets(
          bitcoin: DefaultWallet(
            walletType: WalletAddressType.bitcoin,
            address: 'bc1qsaved',
          ),
        ),
        editingWalletType: WalletAddressType.bitcoin,
        bitcoinAddressInput: 'bc1qsaved',
      ),
      DefaultWalletsState(
        defaultWallets: DefaultWallets(
          bitcoin: DefaultWallet(
            walletType: WalletAddressType.bitcoin,
            address: 'bc1qsaved',
          ),
        ),
        editingWalletType: WalletAddressType.bitcoin,
        bitcoinAddressInput: 'bc1qchanged',
      ),
      DefaultWalletsState(
        defaultWallets: DefaultWallets(
          bitcoin: DefaultWallet(
            walletType: WalletAddressType.bitcoin,
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
    act: (cubit) => cubit.saveWallet(WalletAddressType.bitcoin),
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
        () => validateDestination.execute(
          WalletAddressType.bitcoin,
          'user@example.com',
        ),
      ).thenAnswer((_) async => null);
      final cubit = buildCubit();
      cubit.startEditing(WalletAddressType.bitcoin);
      cubit.updateBitcoinAddress('user@example.com');
      await cubit.saveWallet(WalletAddressType.bitcoin);
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
      when(() => validateDestination.execute(WalletAddressType.bitcoin, 'old'))
          .thenAnswer((_) => pending.future);
      final cubit = buildCubit();
      cubit.updateBitcoinAddress('old');
      final saving = cubit.saveWallet(WalletAddressType.bitcoin);
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
    when(() => validateDestination.execute(WalletAddressType.bitcoin, 'old'))
        .thenAnswer((_) => pending.future);
    final cubit = buildCubit();
    cubit.startEditing(WalletAddressType.bitcoin);
    cubit.updateBitcoinAddress('old');
    final saving = cubit.saveWallet(WalletAddressType.bitcoin);
    cubit.cancelEditing();
    pending.complete('normalized-old');
    await saving;
    expect(cubit.state.editingWalletType, isNull);
    expect(cubit.state.isSaving, isFalse);
    expect(saveCalls, 0);
    await cubit.close();
  });
}
