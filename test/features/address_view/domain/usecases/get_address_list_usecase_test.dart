import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_address_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_error.dart';
import 'package:bb_mobile/features/address_view/domain/address_view_failure.dart';
import 'package:bb_mobile/features/address_view/domain/usecases/get_address_list_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockWalletAddressRepository extends Mock
    implements WalletAddressRepository {}

/// A wallet id is the descriptor origin, so it embeds the master key
/// fingerprint. Routed through the failing paths below so the test output and
/// the failure can both be searched for it: it must appear in neither.
const _sentinelWalletId = 'wpkh([da7ab10b/84h/0h/0h])';

void main() {
  late MockWalletAddressRepository walletAddresses;
  late GetAddressListUsecase usecase;

  setUp(() {
    walletAddresses = MockWalletAddressRepository();
    usecase = GetAddressListUsecase(walletAddressRepository: walletAddresses);
  });

  AddressViewFailure failureOf(
    Result<List<WalletAddress>, AddressViewFailure> result,
  ) {
    expect(result, isA<Err<List<WalletAddress>, AddressViewFailure>>());
    return (result as Err<List<WalletAddress>, AddressViewFailure>).failure;
  }

  WalletAddress addressAt(int index) => WalletAddress(
    walletId: _sentinelWalletId,
    index: index,
    address: 'bc1qexample$index',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  group('GetAddressListUsecase', () {
    test('maps missing wallet metadata to WalletNotFound without carrying the '
        'wallet id', () async {
      when(
        () => walletAddresses.getGeneratedReceiveAddresses(
          any(),
          limit: any(named: 'limit'),
          fromIndex: any(named: 'fromIndex'),
        ),
      ).thenAnswer((_) async => throw WalletError.notFound(_sentinelWalletId));

      final failure = failureOf(
        await usecase.execute(walletId: _sentinelWalletId, limit: 20),
      );

      expect(failure, isA<AddressViewWalletNotFoundFailure>());
      // The variant has no logMessage field at all, so the fingerprint cannot
      // reach the log file or Sentry through a future consumer.
      expect(failure.logMessage, isNull);
    });

    test('maps a rejected repository future to AddressesUnavailable, keeping '
        'the raw reason out of the failure', () async {
      when(
        () => walletAddresses.getGeneratedReceiveAddresses(
          any(),
          limit: any(named: 'limit'),
          fromIndex: any(named: 'fromIndex'),
        ),
        // `thenAnswer` with an async body — not `thenThrow` — because the
        // repository methods are async: the failure arrives as a rejected
        // future, which a non-async try/catch could not see.
      ).thenAnswer(
        (_) async => throw Exception(
          'bdk failed for descriptor $_sentinelWalletId xprv9sSecret',
        ),
      );

      final failure = failureOf(
        await usecase.execute(walletId: _sentinelWalletId, limit: 20),
      );

      expect(failure, isA<AddressViewAddressesUnavailableFailure>());
      expect(failure.logMessage, '_Exception');
      expect(failure.logMessage, isNot(contains(_sentinelWalletId)));
      expect(failure.logMessage, isNot(contains('xprv')));
    });

    test('returns the receive addresses on success', () async {
      final addresses = [addressAt(1), addressAt(0)];
      when(
        () => walletAddresses.getGeneratedReceiveAddresses(
          any(),
          limit: any(named: 'limit'),
          fromIndex: any(named: 'fromIndex'),
        ),
      ).thenAnswer((_) async => addresses);

      final result = await usecase.execute(
        walletId: _sentinelWalletId,
        limit: 20,
      );

      expect(result, isA<Ok<List<WalletAddress>, AddressViewFailure>>());
      expect(
        (result as Ok<List<WalletAddress>, AddressViewFailure>).value,
        same(addresses),
      );
      verifyNever(
        () => walletAddresses.getUsedChangeAddresses(
          any(),
          limit: any(named: 'limit'),
          fromIndex: any(named: 'fromIndex'),
          descending: any(named: 'descending'),
        ),
      );
    });

    test('routes isChange to the change-address query', () async {
      when(
        () => walletAddresses.getUsedChangeAddresses(
          any(),
          limit: any(named: 'limit'),
          fromIndex: any(named: 'fromIndex'),
          descending: any(named: 'descending'),
        ),
      ).thenAnswer((_) async => [addressAt(3)]);

      final result = await usecase.execute(
        walletId: _sentinelWalletId,
        limit: 20,
        isChange: true,
      );

      expect(result, isA<Ok<List<WalletAddress>, AddressViewFailure>>());
      verifyNever(
        () => walletAddresses.getGeneratedReceiveAddresses(
          any(),
          limit: any(named: 'limit'),
          fromIndex: any(named: 'fromIndex'),
        ),
      );
    });
  });
}
