/// BIP-322 Proof of Funds for BULL: prove and verify control of a set of
/// Bitcoin UTXOs.
///
/// Pure Dart. Wallet key access and on-chain UTXO lookups are injected via the
/// [PrivateKeyResolver] and [ChainLookup] ports, so this package depends on
/// neither BDK nor Electrum nor Flutter — the app supplies those adapters.
library;

export 'src/errors.dart';
export 'src/models.dart';
export 'src/ports.dart';
export 'src/proof_of_funds.dart' show ProofOfFunds;
