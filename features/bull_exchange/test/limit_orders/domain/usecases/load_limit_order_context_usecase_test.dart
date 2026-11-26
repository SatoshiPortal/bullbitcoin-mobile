import 'package:bull_exchange/src/exchange_payout_wallets.dart';
import 'package:bull_exchange/src/limit_orders/domain/limit_listed_wallets.dart';
import 'package:bull_exchange/src/limit_orders/domain/limit_order_flow.dart';
import 'package:bull_exchange/src/limit_orders/domain/usecases/load_limit_order_context_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/testing.dart';

import '../../../buy/buy_test_ports.dart';
import '../../limit_order_fixtures.dart';

Future<ExchangeRead<LimitOrderContext>> _load({
  Result<UserSummary, ExchangeFailure>? summary,
  Result<DefaultWallets, ExchangeFailure>? wallets,
  ExchangeSession signedIn = limitSession,
  BuyTestInventory? inventory,
  LimitListedWallets? listed,
  List<ExchangeEnvironment?>? asked,
}) => LoadLimitOrderContextUsecase(
  exchangeForTesting(
    access: fixedAccessForTesting(ExchangeAccessSignedIn(signedIn)),
    getUserSummary: (environment) async {
      asked?.add(environment);
      return summary ?? Ok(userSummary());
    },
    getDefaultWallets: () async => wallets ?? Ok(limitDefaultWallets()),
    unknownWrites: InMemoryUnknownWriteJournal(),
    readSessionPoint: () async =>
        const Ok((environment: ExchangeEnvironment.mainnet, epoch: 1)),
  ),
  ExchangePayoutWallets(
    inventory ?? BuyTestInventory(const {}),
    BuyTestNative(),
  ),
  listed ?? LimitListedWallets(),
).execute(limitSession);

void main() {
  test('opens with the session summary, its default wallets, the app '
      'wallets of the session networks by id and the journal', () async {
    final asked = <ExchangeEnvironment?>[];
    final inventory = BuyTestInventory({
      BitcoinNetwork.mainnet: [
        walletRegistrationForTesting(
          id: 'w-b',
          network: BitcoinNetwork.mainnet,
        ),
        // Listed for the network but on another one: not offered.
        walletRegistrationForTesting(
          id: 'w-x',
          network: BitcoinNetwork.testnet,
        ),
      ],
      LiquidNetwork.mainnet: [
        walletRegistrationForTesting(id: 'w-a', network: LiquidNetwork.mainnet),
      ],
    });
    final listed = LimitListedWallets();
    final read = await _load(
      asked: asked,
      inventory: inventory,
      listed: listed,
    );
    final context = (read as ReadGot<LimitOrderContext>).value;
    expect(
      [for (final w in context.appWallets) '${w.walletId} ${w.rail.name}'],
      ['w-a liquid', 'w-b bitcoin'],
    );
    expect(context.openEntries, isEmpty);
    expect(asked, [ExchangeEnvironment.mainnet]);
    expect(inventory.asked, [BitcoinNetwork.mainnet, LiquidNetwork.mainnet]);
    expect(listed['w-a']?.id, 'w-a');
    expect(listed['w-x'], isNull);
  });

  test('a wallet list that cannot be read offers no app wallet', () async {
    final read = await _load();
    expect((read as ReadGot<LimitOrderContext>).value.appWallets, isEmpty);
  });

  test('the default wallets of another session are a session rejection, '
      'which wins over an unreachable summary', () async {
    expect(
      await _load(
        signedIn: limitOtherSession,
        summary: const Err(ExchangeNetworkFailure()),
      ),
      isA<ReadSessionRejected<LimitOrderContext>>(),
    );
    expect(
      await _load(summary: const Err(ExchangeNetworkFailure())),
      isA<ReadUnreachable<LimitOrderContext>>(),
    );
  });
}
