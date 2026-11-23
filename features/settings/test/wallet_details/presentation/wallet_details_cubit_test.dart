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
  late List<WalletDetailsState> states;
  late bool closed;

  setUp(() {
    read = _MockReadWalletDetails();
    delete = _MockDeleteWallet();
    cubit = WalletDetailsCubit(read, delete);
    states = [];
    closed = false;
    final subscription = cubit.stream.listen(states.add);
    addTearDown(subscription.cancel);
  });

  tearDown(() async {
    if (!closed) await cubit.close();
  });

  Future<void> closeCubit() async {
    closed = true;
    await cubit.close();
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
    await pumpEventQueue();
    when(() => delete.execute(_walletId)).thenAnswer((_) => gate.future);

    final pending = cubit.delete();
    await pumpEventQueue();

    expect(
      states.last,
      isA<WalletDetailsLoaded>().having(
        (state) => state.isDeleting,
        'isDeleting',
        isTrue,
        reason: 'the screen must show the deletion as running',
      ),
    );
    gate.complete(const Ok(null));
    await pending;

    expect(states.last, isA<WalletDetailsDeleted>());
    verify(() => delete.execute(_walletId)).called(1);
  });

  test('returns to the wallet with the deletion failure', () async {
    loadOk();
    await pumpEventQueue();
    when(() => delete.execute(_walletId))
        .thenAnswer((_) async => const Err(WalletDetailsOngoingSwapsFailure()));

    await cubit.delete();

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

  test('ignores a deletion before the wallet is loaded', () async {
    await cubit.delete();

    expect(cubit.state, isA<WalletDetailsLoading>());
    verifyNever(() => delete.execute(any()));
  });

  test('ignores a second deletion while one is running', () async {
    final gate = Completer<Result<void, WalletDetailsFailure>>();
    loadOk();
    await pumpEventQueue();
    when(() => delete.execute(_walletId)).thenAnswer((_) => gate.future);

    final first = cubit.delete();
    await pumpEventQueue();
    final second = cubit.delete();
    gate.complete(const Ok(null));
    await first;
    await second;

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
    await pumpEventQueue();
    when(() => delete.execute(_walletId)).thenAnswer((_) => gate.future);
    final pending = cubit.delete();
    await pumpEventQueue();
    await closeCubit();
    gate.complete(const Ok(null));

    await expectLater(pending, completes);
    expect(states.last, isNot(isA<WalletDetailsDeleted>()));
  });
}
