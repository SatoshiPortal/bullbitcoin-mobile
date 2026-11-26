import 'package:bull_exchange/src/buy/domain/buy_flow.dart';
import 'package:bull_exchange/src/buy/domain/buy_listed_wallets.dart';
import 'package:bull_exchange/src/exchange_answers.dart';
import 'package:bull_exchange/src/exchange_payout_wallets.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:exchange/exchange.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';

/// Reads what the buy flow opens with (and re-reads after a detour): the
/// session account's summary, the app wallets on the session's bitcoin and
/// liquid networks it can pay out to (recorded in [BuyListedWallets]),
/// whether the payjoin policy allows buys, and the open journal entries.
class LoadBuyContextUsecase {
  final Exchange _exchange;
  final ExchangePayoutWallets _payouts;
  final PayjoinPolicyAccess _payjoinPolicy;
  final BuyListedWallets _listed;

  const LoadBuyContextUsecase(
    this._exchange,
    this._payouts,
    this._payjoinPolicy,
    this._listed,
  );

  Future<ExchangeRead<BuyContext>> execute(ExchangeSession session) async {
    final summary = readOfResult(
      await _exchange.getUserSummary(session.environment),
    );
    final listed = await _wallets(session);
    final payjoinAllowed = switch (await _payjoinPolicy.load()) {
      Ok(:final value) => value.buyEnabled,
      Err() => false,
    };
    // A journal that can't be read leaves no entry to start from; the
    // write gate then refuses the confirm itself (JournalUnreadable).
    final entries = switch (await _exchange.openUnknownWrites()) {
      Ok(:final value) => value,
      Err() => const <UnknownWrite>[],
    };
    if (listed == null) {
      return const ReadUnreachable('payout wallets', isNetwork: false);
    }
    return switch (summary) {
      ReadGot(:final value) => ReadGot(
        BuyContext(
          summary: value,
          wallets: listed,
          payjoinAllowed: payjoinAllowed,
          openEntries: entries,
        ),
      ),
      ReadMissing() => const ReadMissing(),
      ReadUnreachable(:final reason, :final isNetwork) => ReadUnreachable(
        reason,
        isNetwork: isNetwork,
      ),
      ReadSessionRejected(:final why) => ReadSessionRejected(why),
      ReadMalformed(:final reason) => ReadMalformed(reason),
    };
  }

  /// The app wallets on the session's networks; null when a network's
  /// wallets can't be read. Only an on-chain wallet with a local signer can
  /// receive the payout through a payjoin.
  Future<List<BuyPayoutWallet>?> _wallets(ExchangeSession session) async {
    final bitcoin = BitcoinNetwork.fromName(session.environment.name);
    final liquid = LiquidNetwork.fromName(session.environment.name);
    final listed = <BuyPayoutWallet>[];
    for (final network in <Network>[bitcoin, liquid]) {
      switch (await _payouts.walletsForNetwork(network)) {
        case Ok(:final value):
          for (final wallet in value.wallets) {
            if (wallet.network != network) continue;
            _listed.add(wallet);
            listed.add(
              BuyPayoutWallet(
                walletId: wallet.id,
                rail: network is LiquidNetwork
                    ? BtcNetwork.liquid
                    : BtcNetwork.bitcoin,
                label: wallet.label,
                isDefault: wallet.isDefault,
                canPayjoin:
                    network is BitcoinNetwork &&
                    wallet.signer == WalletSigner.local,
              ),
            );
          }
        case Err():
          return null;
      }
    }
    return listed;
  }
}
