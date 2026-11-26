# Saved Bark regtest exit material

This is a real, sanitized fixture captured from a dedicated disposable regtest wallet using bark_bitcoin `0.27.0+bark-0.8.1`. Its native source is Bark `303682063ed7559b06dcf37c5cb37bb7037b943f`. The selected VTXO came from an ordinary pubkey board, not an HTLC payment. Standard native `startExitForVtxos` and `progressExits(2)` created the stored exit material. No new funding, board or blocks were needed for that exit capture.

## Source and sanitization

Native handles were closed before the guarded read-only SQL capture. The capture used one snapshot, pinned schema42/index/identity checks and field-kind/byte-length checks before materialization. It retained one VTXO's exact separate `raw_bare` and `raw_genesis`, one actual Processing state/history and one linked parent/child/origin row. The independent expected manifest was recorded before fixture construction; its SHA256 and source-derived field digests are in `provenance.json`. The lead compared that separate file with the actual capture and reviewed the non-HTLC origin and selected material before publication. Hash equality alone does not establish provenance or absence of secrets.

The fixture was built from the exact full schema in `../bark_schema42.sql`, which retains Bark's MIT license notice. Only migrations, public properties, one VTXO, one exit state and one child-transaction table contain selected rows. All unrelated tables are empty. The source exit's non-null movement reference was explicitly replaced with SQL NULL so no unrelated movement row is copied. VTXO summary columns use disclosed schema defaults; the test namespace is public and does not authenticate a BIP85 parent. The provenance describes these changes rather than claiming whole source-row identity.

No source DB image, WAL, mnemonic, private key, preimage, private key-index hint, checkpoint or unrelated row is included. These are protocol components and stored transaction bytes; the wrapper does not decode consensus, validate signatures/witness completeness, concatenate a Full encoding or retrieve serialized parent transactions. Bark reconstructs parents outside this SQL projection. This fixture proves stored-material retrieval, not successful final exit claim, recovery or Android power-loss behavior.

## Verification and local artifact builder

`test/data/bark_sql_real_exit_material_test.dart` requires this saved fixture without an environment gate or skip. It checks all three public SQL methods, the actual Processing/parent/child link, exact source-derived field digests, integrity/FKs, empty unrelated tables and detached immutable DTO bytes.

The one-shot `test/support/build_saved_fixture.dart` accepts an already reviewed detached JSON bundle, the independently recorded expected JSON file and a new local output directory. It never receives a source database path or wallet/network capability. Run it only with actual reviewed material and prepared workspace dependencies/native assets; do not replace missing input with synthetic positive data. Source strings are preserved without JSON reserialization. The full source database must never be used as the fixture.
