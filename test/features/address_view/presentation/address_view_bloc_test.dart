import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';
import 'package:bb_mobile/features/address_view/domain/address_view_failure.dart';
import 'package:bb_mobile/features/address_view/domain/usecases/check_wallet_is_liquid_usecase.dart';
import 'package:bb_mobile/features/address_view/domain/usecases/get_address_list_usecase.dart';
import 'package:bb_mobile/features/address_view/presentation/address_view_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockGetAddressListUsecase extends Mock implements GetAddressListUsecase {}

class MockCheckWalletIsLiquidUsecase extends Mock
    implements CheckWalletIsLiquidUsecase {}

const _walletId = 'wpkh([f1n6erpr/84h/0h/0h])';

void main() {
  late MockGetAddressListUsecase getAddresses;
  late MockCheckWalletIsLiquidUsecase checkIsLiquid;

  WalletAddress addressAt(int index) => WalletAddress(
    walletId: _walletId,
    index: index,
    address: 'bc1qexample$index',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  AddressViewBloc buildBloc() => AddressViewBloc(
    walletId: _walletId,
    checkWalletIsLiquidUsecase: checkIsLiquid,
    getAddressListUsecase: getAddresses,
    limit: 2,
  );

  setUp(() {
    getAddresses = MockGetAddressListUsecase();
    checkIsLiquid = MockCheckWalletIsLiquidUsecase();
    when(
      () => checkIsLiquid.execute(any()),
    ).thenAnswer((_) async => const Ok(false));
  });

  group('AddressViewBloc', () {
    test(
      'holds the typed failure when the receive list fails to load',
      () async {
        when(
          () => getAddresses.execute(
            walletId: any(named: 'walletId'),
            limit: any(named: 'limit'),
            fromIndex: any(named: 'fromIndex'),
            isChange: any(named: 'isChange'),
          ),
        ).thenAnswer(
          (_) async =>
              const Err(AddressViewAddressesUnavailableFailure('_Exception')),
        );
        final bloc = buildBloc();

        final loaded = bloc.stream.firstWhere((state) => !state.isLoading);
        bloc.add(const AddressViewEvent.loadInitialAddresses());
        final state = await loaded;

        expect(
          state.receiveAddressesFailure,
          isA<AddressViewAddressesUnavailableFailure>(),
        );
        expect(state.isLoading, isFalse);
        await bloc.close();
      },
    );

    test('a failing change list does not blank the receive list', () async {
      when(
        () => getAddresses.execute(
          walletId: any(named: 'walletId'),
          limit: any(named: 'limit'),
          fromIndex: any(named: 'fromIndex'),
          isChange: false,
        ),
      ).thenAnswer((_) async => Ok([addressAt(1), addressAt(0)]));
      when(
        () => getAddresses.execute(
          walletId: any(named: 'walletId'),
          limit: any(named: 'limit'),
          fromIndex: any(named: 'fromIndex'),
          isChange: true,
        ),
      ).thenAnswer((_) async => const Err(AddressViewWalletNotFoundFailure()));
      final bloc = buildBloc();

      final loaded = bloc.stream.firstWhere((state) => !state.isLoading);
      bloc.add(const AddressViewEvent.loadInitialAddresses());
      final state = await loaded;

      expect(state.receiveAddresses, hasLength(2));
      expect(state.receiveAddressesFailure, isNull);
      expect(
        state.changeAddressesFailure,
        isA<AddressViewWalletNotFoundFailure>(),
      );
      await bloc.close();
    });

    test(
      'clears a stale pagination failure when the next page succeeds',
      () async {
        when(
          () => getAddresses.execute(
            walletId: any(named: 'walletId'),
            limit: any(named: 'limit'),
            fromIndex: any(named: 'fromIndex'),
            isChange: any(named: 'isChange'),
          ),
        ).thenAnswer((_) async => Ok([addressAt(3), addressAt(2)]));
        final bloc = buildBloc();

        final loaded = bloc.stream.firstWhere((state) => !state.isLoading);
        bloc.add(const AddressViewEvent.loadInitialAddresses());
        await loaded;

        // Page 2 fails.
        when(
          () => getAddresses.execute(
            walletId: any(named: 'walletId'),
            limit: any(named: 'limit'),
            fromIndex: any(named: 'fromIndex'),
            isChange: any(named: 'isChange'),
          ),
        ).thenAnswer(
          (_) async => const Err(AddressViewAddressesUnavailableFailure()),
        );
        final failed = bloc.stream.firstWhere(
          (state) => state.receiveAddressesFailure != null,
        );
        bloc.add(const AddressViewEvent.loadMoreReceiveAddresses());
        await failed;

        // Page 2 retried and succeeds: the stale error row must not survive.
        when(
          () => getAddresses.execute(
            walletId: any(named: 'walletId'),
            limit: any(named: 'limit'),
            fromIndex: any(named: 'fromIndex'),
            isChange: any(named: 'isChange'),
          ),
        ).thenAnswer((_) async => Ok([addressAt(1), addressAt(0)]));
        final recovered = bloc.stream.firstWhere(
          (state) => !state.isLoading && state.receiveAddressesFailure == null,
        );
        bloc.add(const AddressViewEvent.loadMoreReceiveAddresses());
        final state = await recovered;

        expect(state.receiveAddressesFailure, isNull);
        expect(state.receiveAddresses, hasLength(4));
        await bloc.close();
      },
    );
  });
}
