import 'package:bull_exchange/src/exchange_answers.dart';
import 'package:bull_exchange/src/exchange_payout_wallets.dart';
import 'package:bull_exchange/src/limit_orders/domain/limit_listed_wallets.dart';
import 'package:bull_exchange/src/limit_orders/domain/limit_order_flow.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:exchange/exchange.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';

/// Reads what the limit-order flow opens with (and re-reads after a
/// detour), all at once: the session account's summary, its default
/// wallets, the app wallets on the session's bitcoin and liquid networks
/// (recorded in [LimitListedWallets]) and the open journal entries. A
/// session rejection in either account read wins, then an unreachable one,
/// then a malformed one, then a missing one.
class LoadLimitOrderContextUsecase {
  final Exchange _exchange;
  final ExchangePayoutWallets _payouts;
  final LimitListedWallets _listed;

  const LoadLimitOrderContextUsecase(
    this._exchange,
    this._payouts,
    this._listed,
  );

  Future<ExchangeRead<LimitOrderContext>> execute(
    ExchangeSession session,
  ) async {
    final (summary, defaults, wallets, entries) = await (
      _exchange.getUserSummary(session.environment),
      _exchange.readDefaultWallets(session),
      _appWallets(session),
      _exchange.openUnknownWrites(),
    ).wait;
    final summaryRead = readOfResult(summary);
    // A journal that can't be read leaves no entry to start from; the
    // write gate then refuses the create itself (JournalUnreadable).
    final open = switch (entries) {
      Ok(:final value) => value,
      Err() => const <UnknownWrite>[],
    };
    return switch ((summaryRead, defaults)) {
      (ReadGot(value: final s), ReadGot(value: final d)) => ReadGot(
        LimitOrderContext(s, d, wallets, open),
      ),
      (ReadSessionRejected(:final why), _) ||
      (_, ReadSessionRejected(:final why)) => ReadSessionRejected(why),
      (ReadUnreachable(:final reason, :final isNetwork), _) ||
      (
        _,
        ReadUnreachable(:final reason, :final isNetwork),
      ) => ReadUnreachable(reason, isNetwork: isNetwork),
      (ReadMalformed(:final reason), _) ||
      (_, ReadMalformed(:final reason)) => ReadMalformed(reason),
      (ReadMissing(), _) || (_, ReadMissing()) => const ReadMissing(),
    };
  }

  /// The app wallets on the session's networks, sorted by id. A network
  /// whose wallets can't be read offers none; the default wallets and a
  /// Lightning address remain.
  Future<List<LimitAppWallet>> _appWallets(ExchangeSession session) async {
    final wallets = <WalletRegistration>[];
    final networks = switch (session.environment) {
      ExchangeEnvironment.mainnet => const <Network>[
        BitcoinNetwork.mainnet,
        LiquidNetwork.mainnet,
      ],
      ExchangeEnvironment.testnet => const <Network>[
        BitcoinNetwork.testnet,
        LiquidNetwork.testnet,
      ],
    };
    for (final network in networks) {
      switch (await _payouts.walletsForNetwork(network)) {
        case Ok(:final value):
          wallets.addAll(value.wallets.where((w) => w.network == network));
        case Err(:final failure):
          log.warning(
            'Failed to list wallets for a limit order: ${failure.runtimeType}',
          );
      }
    }
    wallets.sort((left, right) => left.id.compareTo(right.id));
    _listed.replaceAll(wallets);
    return [
      for (final wallet in wallets)
        LimitAppWallet(
          wallet.id,
          wallet.network is LiquidNetwork
              ? BtcNetwork.liquid
              : BtcNetwork.bitcoin,
          label: wallet.label,
        ),
    ];
  }
}
