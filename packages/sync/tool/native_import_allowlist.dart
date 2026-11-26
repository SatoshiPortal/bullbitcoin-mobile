/// Files outside `packages/sync` that still use BDK or LWK, as of the
/// ratchet's introduction. `make native-write-check` fails when a file not
/// listed here uses them, and when a listed file no longer does: entries are
/// only ever removed, never added or renamed into a wider power.
const nativeImportAllowlist = <String>{
  'packages/secrets/lib/src/crypto/derivers/bitcoin_deriver.dart',
  'packages/secrets/lib/src/crypto/derivers/liquid_deriver.dart',
  'packages/secrets/lib/src/crypto/generator.dart',
  'packages/secrets/lib/src/crypto/signers/bitcoin_signer.dart',
  'packages/secrets/lib/src/crypto/signers/liquid_signer.dart',
  // Address and PSBT parsing, already there when satoshifier moved into the
  // workspace from bull_sdk.
  'packages/satoshifier/lib/enums/network.dart',
  'packages/satoshifier/lib/parsers/bitcoin_address_parser.dart',
  'packages/satoshifier/lib/parsers/liquid_address_parser.dart',
  'packages/satoshifier/lib/parsers/psbt_parser.dart',
};
