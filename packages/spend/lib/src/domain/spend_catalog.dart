import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:sync/sync.dart' show WalletKey;

import 'spend_failure.dart';

/// One snapshot of public wallet identity and its optional software signer.
typedef SpendWallet = ({
  WalletKey key,
  ({Fingerprint fingerprint, ScriptType scriptType})? signer,
});

/// The inventory owner supplies current identities; it never exposes secrets
/// or constructs wallets for Spend. Watch-only and external-signer entries
/// return a null software signer even if another wallet has the same origin.
abstract interface class SpendCatalog {
  static SpendCatalog fromInventory(WalletInventory inventory) =>
      _InventorySpendCatalog(inventory);

  Future<Result<SpendWallet, SpendFailure>> resolve(String walletId);
}

final class _InventorySpendCatalog implements SpendCatalog {
  final WalletInventory _inventory;

  const _InventorySpendCatalog(this._inventory);

  @override
  Future<Result<SpendWallet, SpendFailure>> resolve(String walletId) async =>
      switch (await _inventory.readWallet(walletId)) {
        Ok(value: final wallet) when wallet.id == walletId => Ok((
          key: WalletKey(id: wallet.id, network: wallet.network),
          signer: switch ((wallet.signer, wallet.secretFingerprint)) {
            (WalletSigner.local, final fingerprint?) => (
              fingerprint: fingerprint,
              scriptType: wallet.scriptType,
            ),
            _ => null,
          },
        )),
        _ => const Err(SpendUnavailableFailure()),
      };
}
