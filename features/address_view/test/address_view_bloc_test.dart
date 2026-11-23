import 'package:primitives/primitives.dart';
import 'package:address_view/address_view.dart';
import 'package:address_view/src/presentation/address_view_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAddressView extends Mock implements AddressView {}

const _walletId = 'wpkh([f1n6erpr/84h/0h/0h])';

void main() {
  late MockAddressView getAddresses;

  WalletAddress addressAt(int index) => WalletAddress(
    walletId: _walletId,
    index: index,
    address: 'bc1qexample$index',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  AddressViewBloc buildBloc() =>
      AddressViewBloc(walletId: _walletId, addresses: getAddresses, limit: 2);

  setUp(() {
    getAddresses = MockAddressView();
    when(() => getAddresses.isLiquid(any()))
        .thenAnswer((_) async => const Ok(false));
  });

  group('AddressViewBloc', () {
    test(
      'holds the typed failure when the receive list fails to load',
      () async {
        when(
          () => getAddresses.list(
            walletId: any(named: 'walletId'),
            limit: any(named: 'limit'),
            fromIndex: any(named: 'fromIndex'),
            change: any(named: 'change'),
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
        () => getAddresses.list(
          walletId: any(named: 'walletId'),
          limit: any(named: 'limit'),
          fromIndex: any(named: 'fromIndex'),
          change: false,
        ),
      ).thenAnswer((_) async => Ok([addressAt(1), addressAt(0)]));
      when(
        () => getAddresses.list(
          walletId: any(named: 'walletId'),
          limit: any(named: 'limit'),
          fromIndex: any(named: 'fromIndex'),
          change: true,
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
          () => getAddresses.list(
            walletId: any(named: 'walletId'),
            limit: any(named: 'limit'),
            fromIndex: any(named: 'fromIndex'),
            change: any(named: 'change'),
          ),
        ).thenAnswer((_) async => Ok([addressAt(3), addressAt(2)]));
        final bloc = buildBloc();

        final loaded = bloc.stream.firstWhere((state) => !state.isLoading);
        bloc.add(const AddressViewEvent.loadInitialAddresses());
        await loaded;

        // Page 2 fails.
        when(
          () => getAddresses.list(
            walletId: any(named: 'walletId'),
            limit: any(named: 'limit'),
            fromIndex: any(named: 'fromIndex'),
            change: any(named: 'change'),
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
          () => getAddresses.list(
            walletId: any(named: 'walletId'),
            limit: any(named: 'limit'),
            fromIndex: any(named: 'fromIndex'),
            change: any(named: 'change'),
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
