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
/// seed  → BIP85 39'/0'/12'/104'     → words
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

/// BIP85 entropy at `m/83696968'/39'/0'/12'/104'`, the reserved words path.
/// The words are its first 16 bytes, per BIP85.
const backupCredentialVectorBip85Entropy =
    '3f0471e174312b1f35ba7499bf731cc48bb7bb784f28901ab8f29294c8642933'
    'a0e5af1204b23574bd98ab15e6478eb06f287bf7999bd7b1f0ae7b58bad9d56f';

const backupCredentialVectorWords =
    'disease castle joke trick bargain moon street excess often wine shrimp math';

/// The BIP39 entropy those twelve words carry.
const backupCredentialVectorWordEntropy = '3f0471e174312b1f35ba7499bf731cc4';

/// The BIP39 seed of the words with an empty passphrase: the root every key
/// below is a BIP85 child of.
const backupCredentialVectorWordsSeed =
    '5620587494b3a17ec427807508a060b76c1eae5657af725a538b04c1880c23a0'
    'd5d72871d952303cf9f1ea4246cf8dfbd6482698ad88768e2755a2791e26e2cb';

const backupCredentialVectorEncryptionKey =
    'ce2a7ab7cf46feb693affaa260bc8d04e2dbc84133a584babb7190d1d908b54d';

const backupCredentialVectorNostrPublicKey =
    '0fdb1c5c722922e851f0068d11ef8d201ad4c58f9c0d00cd19e056092f869a26';

const backupCredentialVectorNostrNpub =
    'npub1pld3chrj9y3ws50sq6x3rmudyqddf3v0nsxspngeuptqjtuxngnq7uevnz';

const backupCredentialVectorServerPublicKey =
    'ffaf8fd8b50e1ac50d8cd44a22c0a138ec8d73544421c83c96a6085ed89cc30d';

/// The digest both frozen signatures cover.
const backupCredentialVectorDigest =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

/// BIP340 with the signer's deterministic aux, SHA-256(digest ‖ secret).
const backupCredentialVectorNostrSignature =
    '02cf280e73d20cc8f16cd9f140a8ce422c6da9063674696431961248ee7a42ad'
    '476fa71990616465ee31f38430e5673d80198f41f66b670e73f674a7d084673f';

const backupCredentialVectorServerSignature =
    '80da7a901470f0f4cc793de242d10c477b574fc91e49b767f69a3e0147cc5fa4'
    '47d1c660c744c2855663b3fffebb17989767ba6041648d2e84bef7d85eacad27';

/// A different valid twelve-word credential, for wrong-credential cases.
const backupCredentialVectorOtherWords =
    'abandon abandon abandon abandon abandon abandon abandon abandon '
    'abandon abandon abandon about';
