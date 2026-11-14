/// Files outside `packages/sync` that still use BDK or LWK, as of the
/// ratchet's introduction. `make native-write-check` fails when a file not
/// listed here uses them, and when a listed file no longer does: entries are
/// only ever removed, never added or renamed into a wider power.
const nativeImportAllowlist = <String>{
  'lib/features/replace_by_fee/domain/bump_fee_usecase.dart',
  'lib/features/wallet/data/bdk_wallet_datasource.dart',
  'lib/features/wallet/data/lwk_wallet_datasource.dart',
  'lib/features/wallet/data/wallet_metadata_service.dart',
  'lib/features/wallet/data/wallet_native_runtime.dart',
  'lib/features/wallet/data/wallet_repository.dart',
  'packages/bull_payjoin/lib/src/engine/bitcoin_tx.dart',
  'packages/secrets/lib/src/crypto/derivers/bitcoin_deriver.dart',
  'packages/secrets/lib/src/crypto/derivers/liquid_deriver.dart',
  'packages/secrets/lib/src/crypto/generator.dart',
  'packages/secrets/lib/src/crypto/signers/bitcoin_signer.dart',
  'packages/secrets/lib/src/crypto/signers/liquid_signer.dart',
};
