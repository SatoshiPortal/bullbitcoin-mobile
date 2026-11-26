import 'package:bull_ark/bull_ark.dart';
import 'package:swap_feature/testing.dart';
import 'package:primitives/primitives.dart';

ArkTransferContext transferContext({
  bool stale = false,
  int minimum = 50000,
  String source = 'bitcoin',
}) {
  final account = ArkAccountId(
    parent: Fingerprint('00112233'),
    network: BitcoinNetwork.regtest,
    serverIdentity: 'http://ark.invalid',
  );
  return ArkTransferContext(
    config: ArkAccountConfig(
      id: account,
      arkUrl: Uri.parse('http://ark.invalid'),
      primaryEsploraUrl: Uri.parse('http://chain.invalid'),
    ),
    boardSourceWalletId: source,
    snapshot: ArkSnapshot(
      account: account,
      revision: 1,
      observedAt: DateTime.utc(2026, 11, 17),
      stale: stale,
      spendable: Sats.fromInt(245000),
      serverInfo: ArkServerInfo(
        publicKey: 'public-server',
        minimumBoard: Sats.fromInt(minimum),
      ),
    ),
  );
}

TransferWallet transferWallet({
  String id = 'bitcoin',
  TransferWalletKind kind = TransferWalletKind.bitcoin,
  BigInt? balance,
  bool unknown = false,
  bool canSend = true,
  BitcoinNetwork network = BitcoinNetwork.regtest,
}) => TransferWallet(
  id: id,
  label: kind == TransferWalletKind.bitcoin
      ? 'Secure Bitcoin'
      : kind == TransferWalletKind.liquid
      ? 'Instant payments'
      : 'Ark',
  kind: kind,
  network: network,
  balance: unknown ? null : balance ?? BigInt.from(184250),
  canSend: canSend,
);

TransferWallet get arkTransferWallet =>
    transferWallet(id: 'ark', kind: TransferWalletKind.ark);
