import 'dart:async';

import 'package:bull_exchange/src/default_wallets/domain/default_wallets_state.dart';
import 'package:bull_exchange/src/default_wallets/domain/default_wallets_event.dart';
import 'package:bull_exchange/src/default_wallets/presentation/default_wallets_bloc.dart';
import 'package:exchange/exchange.dart';
import 'package:flutter_test/flutter_test.dart';

import '../default_wallets_usecase_fakes.dart';

import 'package:primitives/primitives.dart';

const _s = ExchangeSession(
  environment: ExchangeEnvironment.mainnet,
  epoch: 1,
  sessionId: 's',
);
const _btc = BtcNetwork.bitcoin;

Never _unused(String call) => throw StateError('$call was not expected');

/// Builds the bloc over fakes; every call is logged with its session.
DefaultWalletsBloc _bloc({
  ExchangeSession? session = _s,
  required List<String> calls,
  Future<Result<DefaultWallets, ExchangeReadFailure>> Function()? read,
  Future<Result<DefaultWallet, ExchangeGatedWriteFailure>> Function(
    String? existingRecipientId,
  )?
  save,
  Future<Result<void, ExchangeGatedWriteFailure>> Function()? unset,
  Future<Result<DefaultWallets, ExchangeReadFailure>> Function()? verify,
}) => DefaultWalletsBloc(
  session: session,
  getWallets: FakeGetDefaultWalletsUsecase((session) {
    calls.add('read ${session.sessionId}');
    return read == null ? _unused('read') : read();
  }),
  validateAddress: FakeValidateDefaultWalletDestinationUsecase(
    (_, text) async => WalletAddressValid(text.trim()),
  ),
  saveWallet: FakeSaveDefaultWalletUsecase((
    session, {
    required network,
    required address,
    existingRecipientId,
  }) {
    calls.add('save ${session.sessionId} ${network.name} $address');
    return save == null ? _unused('save') : save(existingRecipientId);
  }),
  unsetWallet: FakeUnsetDefaultWalletUsecase((
    session, {
    required network,
    required recipientId,
    required address,
  }) {
    calls.add('unset ${session.sessionId} ${network.name} $recipientId');
    return unset == null ? _unused('unset') : unset();
  }),
  verifyWallets: FakeVerifyDefaultWalletsUsecase((session) {
    calls.add('verify ${session.sessionId}');
    return verify == null ? _unused('verify') : verify();
  }),
);

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  test('without a session nothing is read', () async {
    final calls = <String>[];
    final bloc = _bloc(session: null, calls: calls);
    addTearDown(bloc.close);
    await _settle();
    expect(bloc.state, const WalletsSessionEnded());
    expect(calls, isEmpty);
  });

  test('an unknown save re-reads, and the next save updates the recipient '
      'it created (DW-2)', () async {
    const created = DefaultWallets(
      bitcoin: DefaultWallet(
        recipientId: 'r-1',
        walletType: BtcNetwork.bitcoin,
        address: 'bc1qnew',
      ),
    );
    final calls = <String>[];
    final saves = <String?>[];
    final bloc = _bloc(
      calls: calls,
      read: () async => const Ok(DefaultWallets()),
      save: (existingRecipientId) async {
        saves.add(existingRecipientId);
        return const Err(ExchangeWriteOutcomeUnknownFailure('receive timeout'));
      },
      verify: () async => const Ok(created),
    );
    addTearDown(bloc.close);
    await _settle();
    bloc
      ..add(const SlotTyped(_btc, 'bc1qnew'))
      ..add(const SlotSavePressed(_btc));
    for (var i = 0; i < 10; i++) {
      await _settle();
    }
    final ready = bloc.state as WalletsReady;
    expect(ready.saved, created);
    expect(ready.slots.bitcoin, const SlotShowing(notice: SlotNoticeSaved()));

    bloc
      ..add(const SlotTyped(_btc, 'bc1qother'))
      ..add(const SlotSavePressed(_btc));
    for (var i = 0; i < 10; i++) {
      await _settle();
    }
    expect(saves, [null, 'r-1']);
    expect(calls, [
      'read s',
      'save s bitcoin bc1qnew',
      'verify s',
      'save s bitcoin bc1qother',
      'verify s',
    ]);
  });

  test('a second unset while one runs sends nothing (DW-4)', () async {
    final release = Completer<Result<void, ExchangeGatedWriteFailure>>();
    final calls = <String>[];
    final bloc = _bloc(
      calls: calls,
      read: () async => const Ok(
        DefaultWallets(
          bitcoin: DefaultWallet(
            recipientId: 'r-1',
            walletType: BtcNetwork.bitcoin,
            address: 'bc1qsaved',
          ),
        ),
      ),
      unset: () => release.future,
    );
    addTearDown(bloc.close);
    await _settle();
    bloc
      ..add(const SlotUnsetPressed(_btc))
      ..add(const SlotUnsetPressed(_btc));
    await _settle();
    expect(calls, ['read s', 'unset s bitcoin r-1']);
    release.complete(const Ok(null));
    await _settle();
    await _settle();
    expect(
      (bloc.state as WalletsReady).slots.bitcoin,
      const SlotShowing(notice: SlotNoticeUnset()),
    );
  });

  test('a result arriving after close is dropped (DW-1)', () async {
    final release = Completer<Result<DefaultWallets, ExchangeReadFailure>>();
    final bloc = _bloc(calls: [], read: () => release.future);
    await bloc.close();
    release.complete(const Ok(DefaultWallets()));
    await _settle();
    expect(bloc.state, const WalletsLoading(_s, 1));
  });
}
