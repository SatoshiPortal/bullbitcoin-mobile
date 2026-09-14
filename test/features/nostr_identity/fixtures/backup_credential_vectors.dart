/// Frozen backup-credential vectors, on a public synthetic seed.
///
/// Every value below was reproduced by an independent Python implementation of
/// BIP32, BIP85, HKDF-SHA256, BIP39 and BIP340 that shares no code with the app
/// (scripted during T3, 2026-09-14). The words, the word entropy and the Nostr
/// public key are the same bytes the earlier portable prototype had already
/// pinned, so `mnemonic-v1`, `encryption-v1` and `nostr-auth-v1` are carried
/// over unchanged; `server-auth-v1` is the value this task adds.
///
/// Test material only. This seed holds no funds and must never hold any.
library;

import 'dart:typed_data';

/// 32 bytes of 99: the prototype's public publishing seed.
final backupCredentialVectorSeed = Uint8List.fromList(List.filled(32, 99));

/// BIP85 entropy at `m/83696968'/1642'/0'/1'`, the reserved backup path.
const backupCredentialVectorBip85Entropy =
    'a5f64a654a1d2cc390253bb890a1426efd4e0779de26ddb0278a3c21516544b8'
    '3cfe16f8c0d2997ac922cae031eefce4758213e3e4652258c385609fe1e00c1e';

const backupCredentialVectorWords =
    'abandon differ wave love claim impact beach put bunker polar fragile crop';

/// The BIP39 entropy those twelve words carry.
const backupCredentialVectorWordEntropy = '0007bbdfc2329ae384dd761e74ed7199';

const backupCredentialVectorEncryptionKey =
    '301375cfd80649921db2be0ad3bb812460bf9a712a256de81704f909f84907f3';

const backupCredentialVectorNostrPublicKey =
    '0e4567d2c920d4bd991a9e472391cc429464f8c621d92c6e87c005800c998c7b';

const backupCredentialVectorServerPublicKey =
    '469a4d1d8ddc1a69886f3f729a02c58b203695627a90a0cf9a3dfda562292ceb';

/// The digest both frozen signatures cover.
const backupCredentialVectorDigest =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

const backupCredentialVectorNostrSignature =
    '384026f15e4e00b0c332ece9c8183db66e021b6db86af261f8c1beda4d0946c6'
    'e3e03d4880db415dbd3e790fa192a1848d49c57a684cdaf6819ce8ccbcec9f5c';

const backupCredentialVectorServerSignature =
    '3c7c9deb11ff5c9a626b6b25435e3081c97651a38d0bc4ade93a58810b8a9dd2'
    'e7779c66c2cddd1cd7169b0f5d3056039b6b109d2522609b12c88ee182f22651';

/// A different valid twelve-word credential, for wrong-credential cases.
const backupCredentialVectorOtherWords =
    'abandon abandon abandon abandon abandon abandon abandon abandon '
    'abandon abandon abandon about';
