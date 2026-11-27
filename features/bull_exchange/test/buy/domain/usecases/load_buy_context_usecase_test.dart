import 'package:bull_exchange/src/buy/domain/buy_state.dart';
import 'package:bull_exchange/src/buy/domain/buy_listed_wallets.dart';
import 'package:bull_exchange/src/buy/domain/usecases/load_buy_context_usecase.dart';
import 'package:bull_exchange/src/exchange_payout_wallets.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

import '../../buy_fixtures.dart';
import '../../buy_test_ports.dart';

final _local = walletRegistrationForTesting(
  id: 'w-btc',
  network: BitcoinNetwork.mainnet,
  label: 'Savings',
  signer: WalletSigner.local,
);
final _watchOnly = walletRegistrationForTesting(
  id: 'w-watch',
  network: BitcoinNetwork.mainnet,
);
final _liquid = walletRegistrationForTesting(
  id: 'w-lq',
  network: LiquidNetwork.mainnet,
  isDefault: true,
  signer: WalletSigner.local,
);

Future<(Result<BuyContext, ExchangeReadFailure>, BuyListedWallets)> _load({
  required BuyTestInventory inventory,
  bool? buyEnabled = true,
  Future<Result<UserSummary, ExchangeFailure>> Function(ExchangeEnvironment?)?
  summary,
}) async {
  final listed = BuyListedWallets();
  final read = await LoadBuyContextUsecase(
    exchangeForTesting(
      getUserSummary: summary ?? (_) async => Ok(buySummary),
      unknownWrites: InMemoryUnknownWriteJournal(),
      readSessionPoint: () async =>
          const Ok((environment: ExchangeEnvironment.mainnet, epoch: 1)),
    ),
    ExchangePayoutWallets(inventory, BuyTestNative()),
    BuyTestPolicy(buyEnabled: buyEnabled),
    listed,
  ).execute(buySession);
  return (read, listed);
}

void main() {
  test('opens with the summary and the app wallets on the session '
      'networks; only a local on-chain signer can payjoin', () async {
    final asked = <ExchangeEnvironment?>[];
    final inventory = BuyTestInventory({
      BitcoinNetwork.mainnet: [_local, _watchOnly],
      LiquidNetwork.mainnet: [_liquid],
    });
    final (read, listed) = await _load(
      inventory: inventory,
      summary: (environment) async {
        asked.add(environment);
        return Ok(buySummary);
      },
    );
    final context = (read as Ok<BuyContext, ExchangeReadFailure>).value;
    expect(context.summary, buySummary);
    expect(context.wallets, const [
      BuyPayoutWallet(
        walletId: 'w-btc',
        rail: BtcNetwork.bitcoin,
        label: 'Savings',
        canPayjoin: true,
      ),
      BuyPayoutWallet(walletId: 'w-watch', rail: BtcNetwork.bitcoin),
      BuyPayoutWallet(
        walletId: 'w-lq',
        rail: BtcNetwork.liquid,
        isDefault: true,
      ),
    ]);
    expect(context.payjoinAllowed, isTrue);
    expect(context.openEntries, isEmpty);
    expect(asked, [ExchangeEnvironment.mainnet]);
    expect(inventory.asked, [BitcoinNetwork.mainnet, LiquidNetwork.mainnet]);
    expect(listed['w-lq'], same(_liquid));
    expect(listed['w-other'], isNull);
  });

  test('payjoin is offered only when the policy allows buys', () async {
    for (final enabled in [false, null]) {
      final (read, _) = await _load(
        inventory: BuyTestInventory({
          BitcoinNetwork.mainnet: [_local],
          LiquidNetwork.mainnet: const [],
        }),
        buyEnabled: enabled,
      );
      expect(
        (read as Ok<BuyContext, ExchangeReadFailure>).value.payjoinAllowed,
        isFalse,
      );
    }
  });

  test('unreadable wallets are unreachable, even with a summary', () async {
    final (read, _) = await _load(
      inventory: BuyTestInventory({
        BitcoinNetwork.mainnet: [_local],
      }),
    );
    expect(
      read,
      isA<Err<BuyContext, ExchangeReadFailure>>().having(
        (r) => r.failure,
        'failure',
        isA<ExchangeUnreachableFailure>()
            .having((r) => r.reason, 'reason', 'payout wallets')
            .having((r) => r.isNetwork, 'isNetwork', isFalse),
      ),
    );
  });

  test('a failed summary read is the answer', () async {
    final (read, _) = await _load(
      inventory: BuyTestInventory({
        BitcoinNetwork.mainnet: const [],
        LiquidNetwork.mainnet: const [],
      }),
      summary: (_) async => const Err(
        ExchangeSessionRejectedFailure(ExchangeSessionRejection.server),
      ),
    );
    expect(
      read,
      isA<Err<BuyContext, ExchangeReadFailure>>().having(
        (r) => r.failure,
        'failure',
        isA<ExchangeSessionRejectedFailure>(),
      ),
    );
  });
}
