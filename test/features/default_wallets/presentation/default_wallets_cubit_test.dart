import 'package:bb_mobile/core/exchange/domain/entity/default_wallet.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/delete_default_wallet_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_default_wallets_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/save_default_wallet_usecase.dart';
import 'package:bb_mobile/features/default_wallets/presentation/default_wallets_cubit.dart';
import 'package:bb_mobile/features/default_wallets/presentation/default_wallets_state.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockGetDefaultWalletsUsecase extends Mock
    implements GetDefaultWalletsUsecase {}

class MockSaveDefaultWalletUsecase extends Mock
    implements SaveDefaultWalletUsecase {}

class MockDeleteDefaultWalletUsecase extends Mock
    implements DeleteDefaultWalletUsecase {}

void main() {
  late MockGetDefaultWalletsUsecase getWallets;
  late MockSaveDefaultWalletUsecase saveWallet;
  late MockDeleteDefaultWalletUsecase deleteWallet;

  DefaultWalletsCubit buildCubit() => DefaultWalletsCubit(
    getDefaultWalletsUsecase: getWallets,
    saveDefaultWalletUsecase: saveWallet,
    deleteDefaultWalletUsecase: deleteWallet,
  );

  setUpAll(() => registerFallbackValue(WalletAddressType.bitcoin));

  setUp(() {
    getWallets = MockGetDefaultWalletsUsecase();
    saveWallet = MockSaveDefaultWalletUsecase();
    deleteWallet = MockDeleteDefaultWalletUsecase();
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
      when(() => getWallets.execute()).thenAnswer((_) async => savedWallets);
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
      DefaultWalletsState(saveError: 'Address cannot be empty'),
    ],
    verify: (_) {
      verifyNever(
        () => saveWallet.execute(
          walletType: any(named: 'walletType'),
          address: any(named: 'address'),
          existingRecipientId: any(named: 'existingRecipientId'),
        ),
      );
    },
  );
}
