import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:settings/src/wallet_details/domain/delete_wallet_usecase.dart';
import 'package:settings/src/wallet_details/domain/read_wallet_details_usecase.dart';
import 'package:settings/src/wallet_details/domain/wallet_details.dart';
import 'package:settings/src/wallet_details/domain/wallet_details_failure.dart';
import 'package:settings/src/wallet_details/presentation/wallet_details_cubit.dart';

class _MockReadWalletDetails extends Mock implements ReadWalletDetailsUsecase {}

class _MockDeleteWallet extends Mock implements DeleteWalletUsecase {}

const _walletId = 'wpkh([0a1b2c3d/84h/0h/0h])';

final _details = WalletDetails(
  id: _walletId,
  label: 'Savings',
  isDefault: false,
  network: BitcoinNetwork.mainnet,
  scriptType: ScriptType.bip84,
  masterFingerprint: '0a1b2c3d',
  xpub: 'xpub-marker',
  externalDescriptor: 'wpkh([0a1b2c3d/84h/0h/0h]xpub-marker/0/*)',
  signer: SignerEntity.none,
  signerDevice: null,
);

void main() {
  late _MockReadWalletDetails read;
  late _MockDeleteWallet delete;
  late WalletDetailsCubit cubit;
  late StreamController<bool> locks;
  late List<WalletDetailsState> states;
  late Completer<void> stateDelivered;
  late bool streamClosed;
  late bool closed;

  setUp(() {
    read = _MockReadWalletDetails();
    delete = _MockDeleteWallet();
    locks = StreamController<bool>.broadcast(sync: true);
    addTearDown(locks.close);
    cubit = WalletDetailsCubit(read, delete, locks.stream);
    states = [];
    closed = false;
    streamClosed = false;
    stateDelivered = Completer<void>();
    final subscription = cubit.stream.listen(
      (state) {
        states.add(state);
        final delivered = stateDelivered;
        stateDelivered = Completer<void>();
        delivered.complete();
      },
      onDone: () {
        streamClosed = true;
        if (!stateDelivered.isCompleted) stateDelivered.complete();
      },
    );
    addTearDown(subscription.cancel);
  });

  tearDown(() async {
    if (!closed) await cubit.close();
  });

  Future<void> closeCubit() async {
    closed = true;
    await cubit.close();
  }

  /// Waits until the cubit has delivered [count] states, so an assertion reads
  /// a settled history instead of racing the asynchronous cubit stream.
  Future<void> waitForStates(int count) async {
    while (states.length < count) {
      if (streamClosed) {
        fail('the cubit closed after ${states.length} states, expected $count');
      }
      await stateDelivered.future;
    }
  }

  WalletDetailsCubit loadOk() {
    when(() => read.execute(_walletId)).thenAnswer((_) async => Ok(_details));
    cubit.load(_walletId);
    return cubit;
  }

  test('starts loading', () {
    expect(cubit.state, isA<WalletDetailsLoading>());
  });

  test('publishes the wallet it read', () async {
    when(() => read.execute(_walletId)).thenAnswer((_) async => Ok(_details));

    await cubit.load(_walletId);
    await waitForStates(1);

    expect(states, hasLength(1));
    expect(
      states.single,
      isA<WalletDetailsLoaded>()
          .having((state) => state.details.id, 'details.id', _walletId)
          .having((state) => state.isDeleting, 'isDeleting', isFalse)
          .having((state) => state.deletionFailure, 'deletionFailure', isNull),
    );
  });

  test('reports a wallet it could not read', () async {
    when(() => read.execute(_walletId))
        .thenAnswer((_) async => const Err(WalletDetailsNotFoundFailure()));

    await cubit.load(_walletId);
    await waitForStates(1);

    expect(
      states.single,
      isA<WalletDetailsMissing>().having(
        (state) => state.failure,
        'failure',
        isA<WalletDetailsNotFoundFailure>(),
      ),
    );
  });

  test('reports progress, then the deletion', () async {
    final gate = Completer<Result<void, WalletDetailsFailure>>();
    loadOk();
    await waitForStates(1);
    when(() => delete.execute(_walletId)).thenAnswer((_) => gate.future);

    final pending = cubit.delete();
    await waitForStates(2);

    expect(
      states.last,
      isA<WalletDetailsLoaded>().having(
        (state) => state.isDeleting,
        'isDeleting',
        isTrue,
      ),
      reason: 'the screen must show the deletion as running',
    );
    gate.complete(const Ok(null));
    await pending;
    await waitForStates(3);

    expect(states.last, isA<WalletDetailsDeleted>());
    verify(() => delete.execute(_walletId)).called(1);
  });

  test('returns to the wallet with the deletion failure', () async {
    loadOk();
    await waitForStates(1);
    when(() => delete.execute(_walletId))
        .thenAnswer((_) async => const Err(WalletDetailsOngoingSwapsFailure()));

    await cubit.delete();
    await waitForStates(3);

    expect(
      states.last,
      isA<WalletDetailsLoaded>()
          .having((state) => state.details.id, 'details.id', _walletId)
          .having((state) => state.isDeleting, 'isDeleting', isFalse)
          .having(
            (state) => state.deletionFailure,
            'deletionFailure',
            isA<WalletDetailsOngoingSwapsFailure>(),
          ),
    );
  });

  test(
    'a revocation during deletion publishes nothing of the old session',
    () async {
      loadOk();
      await waitForStates(1);
      final gate = Completer<Result<void, WalletDetailsFailure>>();
      when(() => delete.execute(_walletId)).thenAnswer((_) => gate.future);

      final pending = cubit.delete();
      await waitForStates(2);
      locks.add(true);
      await waitForStates(3);
      expect(states.last, isA<WalletDetailsLoading>());

      gate.complete(const Ok(null));
      await pending;
      await Future<void>.delayed(Duration.zero);

      expect(states, hasLength(3), reason: 'no Deleted or failure afterwards');
    },
  );

  test(
    'a revocation during the load drops its result and the next unlock reloads',
    () async {
      final gate = Completer<Result<WalletDetails, WalletDetailsFailure>>();
      when(() => read.execute(_walletId)).thenAnswer((_) => gate.future);

      final pending = cubit.load(_walletId);
      locks.add(true);
      gate.complete(Ok(_details));
      await pending;
      await Future<void>.delayed(Duration.zero);
      expect(states.whereType<WalletDetailsLoaded>(), isEmpty);

      when(() => read.execute(_walletId))
          .thenAnswer((_) async => const Err(WalletDetailsNotFoundFailure()));
      locks.add(false);
      await waitForStates(states.length + 1);

      expect(states.last, isA<WalletDetailsMissing>());
    },
  );

  test('ignores a deletion before the wallet is loaded', () async {
    await cubit.delete();

    expect(cubit.state, isA<WalletDetailsLoading>());
    verifyNever(() => delete.execute(any()));
  });

  test('ignores a second deletion while one is running', () async {
    final gate = Completer<Result<void, WalletDetailsFailure>>();
    loadOk();
    await waitForStates(1);
    when(() => delete.execute(_walletId)).thenAnswer((_) => gate.future);

    final first = cubit.delete();
    await waitForStates(2);
    final second = cubit.delete();
    gate.complete(const Ok(null));
    await first;
    await second;
    await waitForStates(3);

    verify(() => delete.execute(_walletId)).called(1);
    expect(states.last, isA<WalletDetailsDeleted>());
  });

  test('a late read cannot emit after the cubit is closed', () async {
    final gate = Completer<Result<WalletDetails, WalletDetailsFailure>>();
    when(() => read.execute(_walletId)).thenAnswer((_) => gate.future);
    final pending = cubit.load(_walletId);
    await closeCubit();
    gate.complete(Ok(_details));

    await expectLater(pending, completes);
    expect(states, isEmpty);
  });

  test('a late deletion cannot emit after the cubit is closed', () async {
    final gate = Completer<Result<void, WalletDetailsFailure>>();
    loadOk();
    await waitForStates(1);
    when(() => delete.execute(_walletId)).thenAnswer((_) => gate.future);
    final pending = cubit.delete();
    await waitForStates(2);
    await closeCubit();
    gate.complete(const Ok(null));

    await expectLater(pending, completes);
    expect(states.last, isNot(isA<WalletDetailsDeleted>()));
  });
}
