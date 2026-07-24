import 'package:bb_mobile/core/wallet/data/repositories/wallet_address_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/await_cbf_sync_inactive_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_receive_address_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWalletAddressRepository extends Mock
    implements WalletAddressRepository {}

class _MockAwaitCbfSyncInactiveUsecase extends Mock
    implements AwaitCbfSyncInactiveUsecase {}

WalletAddress _buildAddress({String walletId = 'wallet-1', int index = 0}) {
  return WalletAddress(
    walletId: walletId,
    index: index,
    address: 'bc1qfakeaddress',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

void main() {
  late _MockWalletAddressRepository walletAddressRepository;
  late _MockAwaitCbfSyncInactiveUsecase awaitCbfSyncInactive;
  late GetReceiveAddressUsecase usecase;

  const walletId = 'wallet-1';

  setUp(() {
    walletAddressRepository = _MockWalletAddressRepository();
    awaitCbfSyncInactive = _MockAwaitCbfSyncInactiveUsecase();

    usecase = GetReceiveAddressUsecase(
      walletAddressRepository: walletAddressRepository,
      awaitCbfSyncInactiveUsecase: awaitCbfSyncInactive,
    );

    when(
      () => awaitCbfSyncInactive.execute(walletId: any(named: 'walletId')),
    ).thenAnswer((_) async {});
  });

  test('waits for the active CBF sync to settle before generating a new '
      'address', () async {
    when(
      () =>
          walletAddressRepository.generateNewReceiveAddress(walletId: walletId),
    ).thenAnswer((_) async => _buildAddress());

    final address = await usecase.execute(
      walletId: walletId,
      generateNew: true,
    );

    expect(address, isNotNull);
    verifyInOrder([
      () => awaitCbfSyncInactive.execute(walletId: walletId),
      () =>
          walletAddressRepository.generateNewReceiveAddress(walletId: walletId),
    ]);
  });

  test('waits for the active CBF sync to settle before resolving the last '
      'revealed address (which may itself reveal one)', () async {
    when(
      () => walletAddressRepository.getLastRevealedReceiveAddress(
        walletId: walletId,
      ),
    ).thenAnswer((_) async => _buildAddress());

    await usecase.execute(walletId: walletId);

    verifyInOrder([
      () => awaitCbfSyncInactive.execute(walletId: walletId),
      () => walletAddressRepository.getLastRevealedReceiveAddress(
        walletId: walletId,
      ),
    ]);
  });

  test('never cancels anything — it only ever awaits settlement, and the '
      'wait resolves immediately when no CBF sync is active', () async {
    when(
      () => walletAddressRepository.getLastRevealedReceiveAddress(
        walletId: walletId,
      ),
    ).thenAnswer((_) async => _buildAddress());

    await usecase.execute(walletId: walletId);

    // AwaitCbfSyncInactiveUsecase itself is the only CBF-facing dependency
    // — there is no cancel usecase in this class's dependency graph at all
    // for a test to assert "never called" against.
    verify(() => awaitCbfSyncInactive.execute(walletId: walletId)).called(1);
  });

  test('propagates as GetReceiveAddressException when the address reveal '
      'itself fails', () async {
    when(
      () =>
          walletAddressRepository.generateNewReceiveAddress(walletId: walletId),
    ).thenThrow(Exception('reveal failed'));

    await expectLater(
      usecase.execute(walletId: walletId, generateNew: true),
      throwsA(isA<GetReceiveAddressException>()),
    );
  });

  test(
    'propagates a wait failure without ever calling the address repository',
    () async {
      when(
        () => awaitCbfSyncInactive.execute(walletId: walletId),
      ).thenThrow(Exception('boom'));

      await expectLater(
        usecase.execute(walletId: walletId),
        throwsA(isA<Exception>()),
      );

      verifyNever(
        () => walletAddressRepository.getLastRevealedReceiveAddress(
          walletId: any(named: 'walletId'),
        ),
      );
    },
  );
}
