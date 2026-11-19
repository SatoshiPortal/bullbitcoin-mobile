import 'package:bull_ark/bull_ark.dart';
import 'package:primitives/primitives.dart';

import '../send_failure.dart';

final class SendArkRequest {
  final String destination;
  final List<ArkAccountId> accounts;
  SendArkRequest(this.destination, List<ArkAccountId> accounts)
    : accounts = List.unmodifiable(accounts);
}

/// Pure classification followed by local Ark account admission. No native
/// wallet opens for a paste. Existing Bitcoin/BIP21 parsing remains independent.
final class RecognizeArkAddressUsecase {
  final ArkFacade? _ark;
  const RecognizeArkAddressUsecase(this._ark);
  Future<Result<SendArkRequest?, SendFailure>> execute({
    required String input,
    required Network network,
    required bool restricted,
  }) async {
    final arkNetwork = _network(network);
    final value = input.trim();
    if (!recognizes(value, network)) return const Ok(null);
    if (restricted) return const Err(SendArkRouteUnavailableFailure());
    final ark = _ark;
    if (ark == null) return const Err(SendArkRouteUnavailableFailure());
    switch (await ark.listEnabledAccounts(arkNetwork)) {
      case Err():
        return const Err(SendArkRouteUnavailableFailure());
      case Ok(value: final accounts) when accounts.isEmpty:
        return const Err(SendArkRouteUnavailableFailure());
      case Ok(value: final accounts):
        return Ok(SendArkRequest(value, accounts));
    }
  }

  bool recognizes(String input, Network network) =>
      isArkAddress(input.trim(), network: _network(network));

  static BitcoinNetwork _network(Network network) => switch (network) {
    final BitcoinNetwork bitcoin => bitcoin,
    LiquidNetwork.mainnet => BitcoinNetwork.mainnet,
    LiquidNetwork.testnet => BitcoinNetwork.testnet,
    LiquidNetwork.regtest => BitcoinNetwork.regtest,
  };
}
