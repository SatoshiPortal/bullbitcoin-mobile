/// Frozen backup-credential vectors, on a public synthetic seed.
///
/// Every value below was reproduced by an independent Python implementation of
/// BIP32, BIP85, BIP39 and BIP340 that shares no code with the app. A change
/// to any of them changes what an heir's words open, so they are frozen: a
/// failure here is a compatibility break, not a stale expectation.
///
/// The chain is standard end to end, so any BIP85 tool loaded with the seed
/// prints the words, and loaded with the words prints every key below:
///
/// ```
/// seed  → BIP85 39'/0'/12'/100'     → words
/// words → BIP39 seed, no passphrase → BIP85 128169'/32'/0'  → encryption key
///                                   → BIP85 128002'/100'/1' → artifact identity
///                                   → BIP85 128002'/101'/1' → server identity
/// ```
///
/// Test material only. This seed holds no funds and must never hold any.
library;

import 'dart:typed_data';

/// 32 bytes of 99: a public synthetic seed, chosen for being unmistakable.
final backupCredentialVectorSeed = Uint8List.fromList(List.filled(32, 99));

/// BIP85 entropy at `m/83696968'/39'/0'/12'/100'`, the reserved words path.
/// The words are its first 16 bytes, per BIP85.
const backupCredentialVectorBip85Entropy =
    '1c6cc4b4b40028416da7100f35ca87b4cca7e7b091f0fc33e4a0e381dd541763'
    '901afbf84d9d9480f31ee519ecad536680b9cea6f85df21efc5fc33fa4092bae';

const backupCredentialVectorWords =
    'broccoli great coffee gym action camera repair tilt august purity peanut harbor';

/// The BIP39 entropy those twelve words carry.
const backupCredentialVectorWordEntropy = '1c6cc4b4b40028416da7100f35ca87b4';

/// The BIP39 seed of the words with an empty passphrase: the root every key
/// below is a BIP85 child of.
const backupCredentialVectorWordsSeed =
    'eeb776bae9a83f576a62305391ae0495e605d655a065b3dc520fea371b729330'
    '420f4436f929cd4056d1970965d9d06b5778601940c8e2f03d031ea05270c3d0';

const backupCredentialVectorEncryptionKey =
    '3bb61deff48bde89d721d5a10585b9887240dc9651ec89be69abaee2318d1f4e';

const backupCredentialVectorNostrPublicKey =
    'd740a59a9d059c055d33acf5e670f2712a505a35c8f61124fe1d69eb4a6d336a';

const backupCredentialVectorNostrNpub =
    'npub16aq2tx5aqkwq2hfn4n67vu8jwy49qk34ermpzf87r457kjndxd4q99pfea';

const backupCredentialVectorServerPublicKey =
    'b0ee411ba1a9e79451666debdcb829ca498f848c04458cb951350212eebd1a79';

/// The digest both frozen signatures cover.
const backupCredentialVectorDigest =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

/// BIP340 with the signer's deterministic aux, SHA-256(digest ‖ secret).
const backupCredentialVectorNostrSignature =
    '1704a38cb3f0852769428ae852592e772bf1b55e6007d22db807c83c60911aff'
    '46b3a0d66628f9f4c9f72dec443e7b7b9acfaba663ba6fa980d595c2b827f109';

const backupCredentialVectorServerSignature =
    '3c4217b5bfd7efadbb2b89a9a1c66e29c4843cea7a6d3144d37b2a610db50be4'
    '901630387fa142347e6f53612f7d63dc9a77e820a9f38ed3fc3121eb2d177d2f';

/// A different valid twelve-word credential, for wrong-credential cases.
const backupCredentialVectorOtherWords =
    'abandon abandon abandon abandon abandon abandon abandon abandon '
    'abandon abandon abandon about';
