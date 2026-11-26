import 'dart:async';

import 'package:bull_exchange/src/default_wallets/domain/validate_default_wallet_destination_usecase.dart';
import 'package:bull_exchange/src/default_wallets/presentation/default_wallets_bloc.dart';
import 'package:bull_exchange/src/default_wallets/domain/default_wallets_machine.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

const _s = ExchangeSession(
  environment: ExchangeEnvironment.mainnet,
  epoch: 1,
  sessionId: 's',
);
const _btc = BtcNetwork.bitcoin;

DefaultWalletsBloc _bloc(Exchange exchange) => DefaultWalletsBloc(
  exchange: exchange,
  validateDestination: ValidateDefaultWalletDestinationUsecase(
    (_, raw) async => raw.trim(),
  ),
);

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  test('without a session nothing is read', () async {
    var reads = 0;
    final bloc = _bloc(
      exchangeForTesting(
        getDefaultWallets: () async {
          reads++;
          return const Ok(DefaultWallets());
        },
      ),
    );
    addTearDown(bloc.close);
    await _settle();
    expect(bloc.state, const WalletsSessionEnded());
    expect(reads, 0);
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
    var reads = 0;
    final saves = <String?>[];
    final bloc = _bloc(
      exchangeForTesting(
        access: fixedAccessForTesting(const ExchangeAccessSignedIn(_s)),
        getDefaultWallets: () async =>
            Ok(reads++ == 0 ? const DefaultWallets() : created),
        saveDefaultWallet:
            ({
              required walletType,
              required address,
              existingRecipientId,
            }) async {
              saves.add(existingRecipientId);
              return const WriteOutcomeUnknown('receive timeout');
            },
      ),
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
  });

  test('a second unset while one runs sends nothing (DW-4)', () async {
    final release = Completer<ExchangeWrite<void>>();
    var unsets = 0;
    final bloc = _bloc(
      exchangeForTesting(
        access: fixedAccessForTesting(const ExchangeAccessSignedIn(_s)),
        getDefaultWallets: () async => const Ok(
          DefaultWallets(
            bitcoin: DefaultWallet(
              recipientId: 'r-1',
              walletType: BtcNetwork.bitcoin,
              address: 'bc1qsaved',
            ),
          ),
        ),
        deleteDefaultWallet:
            ({required recipientId, required walletType, required address}) {
              unsets++;
              return release.future;
            },
      ),
    );
    addTearDown(bloc.close);
    await _settle();
    bloc
      ..add(const SlotUnsetPressed(_btc))
      ..add(const SlotUnsetPressed(_btc));
    await _settle();
    expect(unsets, 1);
    release.complete(const WriteDone(null));
    await _settle();
    await _settle();
    expect(
      (bloc.state as WalletsReady).slots.bitcoin,
      const SlotShowing(notice: SlotNoticeUnset()),
    );
  });

  test('a result arriving after close is dropped (DW-1)', () async {
    final release = Completer<Result<DefaultWallets, ExchangeFailure>>();
    final bloc = _bloc(
      exchangeForTesting(
        access: fixedAccessForTesting(const ExchangeAccessSignedIn(_s)),
        getDefaultWallets: () => release.future,
      ),
    );
    await bloc.close();
    release.complete(const Ok(DefaultWallets()));
    await _settle();
    expect(bloc.state, const WalletsLoading(_s, 1));
  });
}
