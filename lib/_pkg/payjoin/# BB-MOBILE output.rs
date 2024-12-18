# BB-MOBILE output

 *  Executing task: cargo test --package payjoin --lib --features send --features receive --features _danger-local-https --features v2 --features io -- send::test::test_receiver_bbmobile_psbt --exact --show-output 

   Compiling payjoin v0.21.0 (/Users/dan/f/dev/payjoin/payjoin)
warning: unused import: `crate::send::SenderBuilder`
   --> payjoin/src/send/mod.rs:911:9
    |
911 |     use crate::send::SenderBuilder;
    |         ^^^^^^^^^^^^^^^^^^^^^^^^^^
    |
    = note: `#[warn(unused_imports)]` on by default

warning: unused variable: `uri`
    --> payjoin/src/send/mod.rs:1021:13
     |
1021 | ...   let uri = Uri::try_from(uri).unwrap().assume_checked().check_pj_supported().unwrap().extras.endpoint.receiver_pubkey().unw...
     |           ^^^ help: if this is intentional, prefix it with an underscore: `_uri`
     |
     = note: `#[warn(unused_variables)]` on by default

warning: unused `Result` in tuple element 1 that must be used
    --> payjoin/src/send/mod.rs:1028:9
     |
1028 |         dbg!(":#?}", before);
     |         ^^^^^^^^^^^^^^^^^^^^
     |
     = note: this `Result` may be an `Err` variant, which should be handled
     = note: `#[warn(unused_must_use)]` on by default
     = note: this warning originates in the macro `$crate::dbg` which comes from the expansion of the macro `dbg` (in Nightly builds, run with -Z macro-backtrace for more info)

warning: unused `Result` in tuple element 1 that must be used
    --> payjoin/src/send/mod.rs:1030:9
     |
1030 |         dbg!("{:#?}", after);
     |         ^^^^^^^^^^^^^^^^^^^^
     |
     = note: this `Result` may be an `Err` variant, which should be handled
     = note: this warning originates in the macro `$crate::dbg` which comes from the expansion of the macro `dbg` (in Nightly builds, run with -Z macro-backtrace for more info)

warning: unused `Result` in tuple element 1 that must be used
    --> payjoin/src/send/mod.rs:1036:9
     |
1036 |         dbg!(":#?}", before);
     |         ^^^^^^^^^^^^^^^^^^^^
     |
     = note: this `Result` may be an `Err` variant, which should be handled
     = note: this warning originates in the macro `$crate::dbg` which comes from the expansion of the macro `dbg` (in Nightly builds, run with -Z macro-backtrace for more info)

warning: unused `Result` in tuple element 1 that must be used
    --> payjoin/src/send/mod.rs:1038:9
     |
1038 |         dbg!("{:#?}", after);
     |         ^^^^^^^^^^^^^^^^^^^^
     |
     = note: this `Result` may be an `Err` variant, which should be handled
     = note: this warning originates in the macro `$crate::dbg` which comes from the expansion of the macro `dbg` (in Nightly builds, run with -Z macro-backtrace for more info)

warning: `payjoin` (lib test) generated 6 warnings (run `cargo fix --lib -p payjoin --tests` to apply 1 suggestion)
    Finished `test` profile [unoptimized + debuginfo] target(s) in 1.43s
     Running unittests src/lib.rs (target/debug/deps/payjoin-f98f70e0cf2645d0)

running 1 test
test send::test::test_receiver_bbmobile_psbt ... ok

successes:

---- send::test::test_receiver_bbmobile_psbt stdout ----
[payjoin/src/send/mod.rs:1036:9] ":#?}" = ":#?}"
[payjoin/src/send/mod.rs:1036:9] before = Ok(
    Psbt {
        unsigned_tx: Transaction {
            version: Version(
                1,
            ),
            lock_time: 3523173 blocks,
            input: [
                TxIn {
                    previous_output: OutPoint {
                        txid: 087bd59ba7d16c544f552582660cc4998a5bdbb45c38cd4b9316146285800bcd,
                        vout: 1,
                    },
                    script_sig: Script(),
                    sequence: Sequence(0xfffffffd),
                    witness: Witness: {
                        indices: 0,
                        indices_start: 0,
                        witnesses: [
                        ],
                    }
                    ,
                },
                TxIn {
                    previous_output: OutPoint {
                        txid: e322c167ac035d8b02167b256aa846d7cfc24e54ad5d4391e344ec2d32e42fb5,
                        vout: 0,
                    },
                    script_sig: Script(),
                    sequence: Sequence(0xfffffffd),
                    witness: Witness: {
                        indices: 0,
                        indices_start: 0,
                        witnesses: [
                        ],
                    }
                    ,
                },
            ],
            output: [
                TxOut {
                    value: 489111123 SAT,
                    script_pubkey: Script(OP_0 OP_PUSHBYTES_20 47e37221e396b243d6fe6f1d02ef777498d93f12),
                },
                TxOut {
                    value: 26946982 SAT,
                    script_pubkey: Script(OP_0 OP_PUSHBYTES_20 827ba6826e31784eea5c0f79f764e85ed90ac91b),
                },
            ],
        },
        version: 0,
        xpub: {},
        proprietary: {},
        unknown: {},
        inputs: [
            Input {
                non_witness_utxo: None,
                witness_utxo: Some(
                    TxOut {
                        value: 16946982 SAT,
                        script_pubkey: Script(OP_0 OP_PUSHBYTES_20 6fab323769dac6b67ea4fb9f85f8de2a11d9e6e4),
                    },
                ),
                partial_sigs: {},
                sighash_type: None,
                redeem_script: None,
                witness_script: None,
                bip32_derivation: {},
                final_script_sig: None,
                final_script_witness: None,
                ripemd160_preimages: {},
                sha256_preimages: {},
                hash160_preimages: {},
                hash256_preimages: {},
                tap_key_sig: None,
                tap_script_sigs: {},
                tap_scripts: {},
                tap_key_origins: {},
                tap_internal_key: None,
                tap_merkle_root: None,
                proprietary: {},
                unknown: {},
            },
            Input {
                non_witness_utxo: Some(
                    Transaction {
                        version: Version(
                            2,
                        ),
                        lock_time: 3522882 blocks,
                        input: [
                            TxIn {
                                previous_output: OutPoint {
                                    txid: 6a22d7cf1bec3c03d46a6defa98eb2d6ecb0997ddc916979651602d80359bb66,
                                    vout: 1,
                                },
                                script_sig: Script(OP_PUSHBYTES_34 0020fad44e01956c38a78f986fc523c95a73e9764cc579d5fed1e4832f0bad683be5),
                                sequence: Sequence(0x0000ca80),
                                witness: Witness: {
                                    indices: 3,
                                    indices_start: 152,
                                    witnesses: [
                                        [],
                                        [0x30, 0x44, 0x02, 0x20, 0x29, 0x77, 0xa3, 0xf2, 0x08, 0x7e, 0x16, 0x2d, 0x49, 0x27, 0x7e, 0xfc, 0x6d, 0x0b, 0x21, 0x26, 0xb6, 0xae, 0x23, 0x01, 0x65, 0xf7, 0x64, 0x4d, 0xba, 0xdf, 0x8a, 0x27, 0x05, 0x4b, 0x99, 0xb0, 0x02, 0x20, 0x30, 0xa4, 0xfa, 0xbf, 0x46, 0x34, 0x49, 0x09, 0x5d, 0x16, 0x26, 0xd2, 0x9c, 0x66, 0x78, 0xf3, 0x85, 0x64, 0xff, 0xd4, 0x40, 0xea, 0xae, 0xe2, 0xe7, 0x1b, 0xf6, 0x45, 0x22, 0xb3, 0x5f, 0xdd, 0x01],
                                        [0x21, 0x02, 0x07, 0xa4, 0xff, 0x4e, 0x66, 0x0a, 0x2a, 0xe6, 0x6a, 0x14, 0x1f, 0x2a, 0x1d, 0x7d, 0x1a, 0xe5, 0x19, 0xa4, 0x68, 0xc0, 0x92, 0xe9, 0x70, 0x81, 0x61, 0xf3, 0xac, 0x92, 0x5e, 0x5a, 0x3a, 0x88, 0xad, 0x21, 0x02, 0x3c, 0x5d, 0xec, 0x13, 0x2d, 0x64, 0x3e, 0x6b, 0xd3, 0x6f, 0x5a, 0xa9, 0xc4, 0xcb, 0xa1, 0x47, 0xa4, 0x44, 0x89, 0x2e, 0xb1, 0x34, 0x91, 0xe8, 0x8d, 0x41, 0x74, 0x72, 0x54, 0x14, 0x5d, 0x9a, 0xac, 0x73, 0x64, 0x03, 0x80, 0xca, 0x00, 0xb2, 0x68],
                                    ],
                                }
                                ,
                            },
                            TxIn {
                                previous_output: OutPoint {
                                    txid: 58e0391c5a37491b3d50bcbcfaf32771516ab674eb9f57dfa38bb8d223f5c2c3,
                                    vout: 1,
                                },
                                script_sig: Script(OP_PUSHBYTES_34 00200f01dd6842d4f1f8193b6447e70b2eab1831cf05a79eb1a55db68e024e90e3ea),
                                sequence: Sequence(0xfffffffd),
                                witness: Witness: {
                                    indices: 3,
                                    indices_start: 222,
                                    witnesses: [
                                        [0x30, 0x44, 0x02, 0x20, 0x25, 0xd7, 0xd6, 0x1d, 0xa7, 0x19, 0xbe, 0xf6, 0x57, 0xb5, 0xa4, 0x6a, 0x50, 0x4e, 0x49, 0x21, 0xc8, 0x9d, 0x17, 0x7a, 0xf3, 0x75, 0x02, 0xe6, 0x00, 0xb2, 0xc3, 0x2b, 0x8e, 0x65, 0x0b, 0x15, 0x02, 0x20, 0x7c, 0xd6, 0x25, 0xfd, 0x87, 0x9a, 0x3d, 0xdc, 0x30, 0xa2, 0xea, 0x11, 0x13, 0xe5, 0xd2, 0xe9, 0xa5, 0xb8, 0x2f, 0xef, 0x76, 0xa0, 0xfb, 0xb8, 0x24, 0x34, 0xa1, 0x16, 0x70, 0x24, 0xd5, 0xa3, 0x01],
                                        [0x30, 0x43, 0x02, 0x1f, 0x54, 0x12, 0x27, 0x9a, 0xe2, 0x15, 0xf6, 0xad, 0x67, 0xc9, 0xee, 0xa1, 0x3e, 0xce, 0x24, 0xee, 0x2e, 0x85, 0x55, 0x46, 0xf9, 0x9a, 0x0e, 0x70, 0xa7, 0x8b, 0xa6, 0x7c, 0x54, 0xc1, 0xab, 0x02, 0x20, 0x4c, 0x08, 0xc3, 0x09, 0xd2, 0xd3, 0x68, 0xc3, 0xd1, 0x9c, 0x6c, 0x4b, 0x0a, 0x39, 0xf3, 0xe7, 0x8a, 0x60, 0xe8, 0x12, 0xf6, 0x7b, 0x27, 0xa6, 0x93, 0x91, 0xa3, 0x3c, 0x29, 0xf7, 0xff, 0xbf, 0x01],
                                        [0x21, 0x02, 0x8c, 0x0b, 0xb0, 0x0c, 0x0a, 0x12, 0x15, 0x88, 0x02, 0x9b, 0x7d, 0x30, 0xb6, 0xdb, 0xc6, 0xc1, 0x15, 0xa8, 0x7c, 0xf7, 0x31, 0xb5, 0x3f, 0x35, 0x3c, 0x56, 0xe4, 0x2d, 0x57, 0x7c, 0xb0, 0x4e, 0xad, 0x21, 0x03, 0x46, 0x4b, 0x0a, 0xb1, 0x1a, 0xdd, 0x05, 0x4a, 0x57, 0x33, 0x17, 0x62, 0x1c, 0x3a, 0x78, 0xa8, 0x4b, 0x2b, 0x97, 0x54, 0x2f, 0x99, 0x4a, 0x53, 0x4a, 0x0f, 0x28, 0xad, 0xa6, 0xe4, 0x6b, 0xc0, 0xac, 0x73, 0x64, 0x03, 0x80, 0xca, 0x00, 0xb2, 0x68],
                                    ],
                                }
                                ,
                            },
                        ],
                        output: [
                            TxOut {
                                value: 500000000 SAT,
                                script_pubkey: Script(OP_0 OP_PUSHBYTES_20 bdb379b0229ac35d5edb234f7bdf792584a93450),
                            },
                            TxOut {
                                value: 8398802298 SAT,
                                script_pubkey: Script(OP_HASH160 OP_PUSHBYTES_20 1521f36ad6ffea107b9925571e1566a8ddfadb73 OP_EQUAL),
                            },
                        ],
                    },
                ),
                witness_utxo: Some(
                    TxOut {
                        value: 500000000 SAT,
                        script_pubkey: Script(OP_0 OP_PUSHBYTES_20 bdb379b0229ac35d5edb234f7bdf792584a93450),
                    },
                ),
                partial_sigs: {},
                sighash_type: None,
                redeem_script: None,
                witness_script: None,
                bip32_derivation: {},
                final_script_sig: None,
                final_script_witness: None,
                ripemd160_preimages: {},
                sha256_preimages: {},
                hash160_preimages: {},
                hash256_preimages: {},
                tap_key_sig: None,
                tap_script_sigs: {},
                tap_scripts: {},
                tap_key_origins: {},
                tap_internal_key: None,
                tap_merkle_root: None,
                proprietary: {},
                unknown: {},
            },
        ],
        outputs: [
            Output {
                redeem_script: None,
                witness_script: None,
                bip32_derivation: {},
                tap_internal_key: None,
                tap_tree: None,
                tap_key_origins: {},
                proprietary: {},
                unknown: {},
            },
            Output {
                redeem_script: None,
                witness_script: None,
                bip32_derivation: {},
                tap_internal_key: None,
                tap_tree: None,
                tap_key_origins: {},
                proprietary: {},
                unknown: {},
            },
        ],
    },
)
[payjoin/src/send/mod.rs:1038:9] "{:#?}" = "{:#?}"
[payjoin/src/send/mod.rs:1038:9] after = Ok(
    Psbt {
        unsigned_tx: Transaction {
            version: Version(
                1,
            ),
            lock_time: 3523173 blocks,
            input: [
                TxIn {
                    previous_output: OutPoint {
                        txid: 087bd59ba7d16c544f552582660cc4998a5bdbb45c38cd4b9316146285800bcd,
                        vout: 1,
                    },
                    script_sig: Script(),
                    sequence: Sequence(0xfffffffd),
                    witness: Witness: {
                        indices: 0,
                        indices_start: 0,
                        witnesses: [
                        ],
                    }
                    ,
                },
                TxIn {
                    previous_output: OutPoint {
                        txid: e322c167ac035d8b02167b256aa846d7cfc24e54ad5d4391e344ec2d32e42fb5,
                        vout: 0,
                    },
                    script_sig: Script(),
                    sequence: Sequence(0xfffffffd),
                    witness: Witness: {
                        indices: 0,
                        indices_start: 0,
                        witnesses: [
                        ],
                    }
                    ,
                },
            ],
            output: [
                TxOut {
                    value: 489111123 SAT,
                    script_pubkey: Script(OP_0 OP_PUSHBYTES_20 47e37221e396b243d6fe6f1d02ef777498d93f12),
                },
                TxOut {
                    value: 26946982 SAT,
                    script_pubkey: Script(OP_0 OP_PUSHBYTES_20 827ba6826e31784eea5c0f79f764e85ed90ac91b),
                },
            ],
        },
        version: 0,
        xpub: {},
        proprietary: {},
        unknown: {},
        inputs: [
            Input {
                non_witness_utxo: None,
                witness_utxo: Some(
                    TxOut {
                        value: 16946982 SAT,
                        script_pubkey: Script(OP_0 OP_PUSHBYTES_20 6fab323769dac6b67ea4fb9f85f8de2a11d9e6e4),
                    },
                ),
                partial_sigs: {},
                sighash_type: None,
                redeem_script: None,
                witness_script: None,
                bip32_derivation: {
                    PublicKey(
                        9ba1321a20f02331238bf697c9d62fdc668d66a82be0712dfc850bdebac18c8cda5042c7bb8e9693c8233803d30670d5f55200ff63891629fbeedf7fb6e6acd4,
                    ): (
                        0xb197883f,
                        84'/1'/0'/1/31,
                    ),
                },
                final_script_sig: None,
                final_script_witness: None,
                ripemd160_preimages: {},
                sha256_preimages: {},
                hash160_preimages: {},
                hash256_preimages: {},
                tap_key_sig: None,
                tap_script_sigs: {},
                tap_scripts: {},
                tap_key_origins: {},
                tap_internal_key: None,
                tap_merkle_root: None,
                proprietary: {},
                unknown: {},
            },
            Input {
                non_witness_utxo: Some(
                    Transaction {
                        version: Version(
                            2,
                        ),
                        lock_time: 3522882 blocks,
                        input: [
                            TxIn {
                                previous_output: OutPoint {
                                    txid: 6a22d7cf1bec3c03d46a6defa98eb2d6ecb0997ddc916979651602d80359bb66,
                                    vout: 1,
                                },
                                script_sig: Script(OP_PUSHBYTES_34 0020fad44e01956c38a78f986fc523c95a73e9764cc579d5fed1e4832f0bad683be5),
                                sequence: Sequence(0x0000ca80),
                                witness: Witness: {
                                    indices: 3,
                                    indices_start: 152,
                                    witnesses: [
                                        [],
                                        [0x30, 0x44, 0x02, 0x20, 0x29, 0x77, 0xa3, 0xf2, 0x08, 0x7e, 0x16, 0x2d, 0x49, 0x27, 0x7e, 0xfc, 0x6d, 0x0b, 0x21, 0x26, 0xb6, 0xae, 0x23, 0x01, 0x65, 0xf7, 0x64, 0x4d, 0xba, 0xdf, 0x8a, 0x27, 0x05, 0x4b, 0x99, 0xb0, 0x02, 0x20, 0x30, 0xa4, 0xfa, 0xbf, 0x46, 0x34, 0x49, 0x09, 0x5d, 0x16, 0x26, 0xd2, 0x9c, 0x66, 0x78, 0xf3, 0x85, 0x64, 0xff, 0xd4, 0x40, 0xea, 0xae, 0xe2, 0xe7, 0x1b, 0xf6, 0x45, 0x22, 0xb3, 0x5f, 0xdd, 0x01],
                                        [0x21, 0x02, 0x07, 0xa4, 0xff, 0x4e, 0x66, 0x0a, 0x2a, 0xe6, 0x6a, 0x14, 0x1f, 0x2a, 0x1d, 0x7d, 0x1a, 0xe5, 0x19, 0xa4, 0x68, 0xc0, 0x92, 0xe9, 0x70, 0x81, 0x61, 0xf3, 0xac, 0x92, 0x5e, 0x5a, 0x3a, 0x88, 0xad, 0x21, 0x02, 0x3c, 0x5d, 0xec, 0x13, 0x2d, 0x64, 0x3e, 0x6b, 0xd3, 0x6f, 0x5a, 0xa9, 0xc4, 0xcb, 0xa1, 0x47, 0xa4, 0x44, 0x89, 0x2e, 0xb1, 0x34, 0x91, 0xe8, 0x8d, 0x41, 0x74, 0x72, 0x54, 0x14, 0x5d, 0x9a, 0xac, 0x73, 0x64, 0x03, 0x80, 0xca, 0x00, 0xb2, 0x68],
                                    ],
                                }
                                ,
                            },
                            TxIn {
                                previous_output: OutPoint {
                                    txid: 58e0391c5a37491b3d50bcbcfaf32771516ab674eb9f57dfa38bb8d223f5c2c3,
                                    vout: 1,
                                },
                                script_sig: Script(OP_PUSHBYTES_34 00200f01dd6842d4f1f8193b6447e70b2eab1831cf05a79eb1a55db68e024e90e3ea),
                                sequence: Sequence(0xfffffffd),
                                witness: Witness: {
                                    indices: 3,
                                    indices_start: 222,
                                    witnesses: [
                                        [0x30, 0x44, 0x02, 0x20, 0x25, 0xd7, 0xd6, 0x1d, 0xa7, 0x19, 0xbe, 0xf6, 0x57, 0xb5, 0xa4, 0x6a, 0x50, 0x4e, 0x49, 0x21, 0xc8, 0x9d, 0x17, 0x7a, 0xf3, 0x75, 0x02, 0xe6, 0x00, 0xb2, 0xc3, 0x2b, 0x8e, 0x65, 0x0b, 0x15, 0x02, 0x20, 0x7c, 0xd6, 0x25, 0xfd, 0x87, 0x9a, 0x3d, 0xdc, 0x30, 0xa2, 0xea, 0x11, 0x13, 0xe5, 0xd2, 0xe9, 0xa5, 0xb8, 0x2f, 0xef, 0x76, 0xa0, 0xfb, 0xb8, 0x24, 0x34, 0xa1, 0x16, 0x70, 0x24, 0xd5, 0xa3, 0x01],
                                        [0x30, 0x43, 0x02, 0x1f, 0x54, 0x12, 0x27, 0x9a, 0xe2, 0x15, 0xf6, 0xad, 0x67, 0xc9, 0xee, 0xa1, 0x3e, 0xce, 0x24, 0xee, 0x2e, 0x85, 0x55, 0x46, 0xf9, 0x9a, 0x0e, 0x70, 0xa7, 0x8b, 0xa6, 0x7c, 0x54, 0xc1, 0xab, 0x02, 0x20, 0x4c, 0x08, 0xc3, 0x09, 0xd2, 0xd3, 0x68, 0xc3, 0xd1, 0x9c, 0x6c, 0x4b, 0x0a, 0x39, 0xf3, 0xe7, 0x8a, 0x60, 0xe8, 0x12, 0xf6, 0x7b, 0x27, 0xa6, 0x93, 0x91, 0xa3, 0x3c, 0x29, 0xf7, 0xff, 0xbf, 0x01],
                                        [0x21, 0x02, 0x8c, 0x0b, 0xb0, 0x0c, 0x0a, 0x12, 0x15, 0x88, 0x02, 0x9b, 0x7d, 0x30, 0xb6, 0xdb, 0xc6, 0xc1, 0x15, 0xa8, 0x7c, 0xf7, 0x31, 0xb5, 0x3f, 0x35, 0x3c, 0x56, 0xe4, 0x2d, 0x57, 0x7c, 0xb0, 0x4e, 0xad, 0x21, 0x03, 0x46, 0x4b, 0x0a, 0xb1, 0x1a, 0xdd, 0x05, 0x4a, 0x57, 0x33, 0x17, 0x62, 0x1c, 0x3a, 0x78, 0xa8, 0x4b, 0x2b, 0x97, 0x54, 0x2f, 0x99, 0x4a, 0x53, 0x4a, 0x0f, 0x28, 0xad, 0xa6, 0xe4, 0x6b, 0xc0, 0xac, 0x73, 0x64, 0x03, 0x80, 0xca, 0x00, 0xb2, 0x68],
                                    ],
                                }
                                ,
                            },
                        ],
                        output: [
                            TxOut {
                                value: 500000000 SAT,
                                script_pubkey: Script(OP_0 OP_PUSHBYTES_20 bdb379b0229ac35d5edb234f7bdf792584a93450),
                            },
                            TxOut {
                                value: 8398802298 SAT,
                                script_pubkey: Script(OP_HASH160 OP_PUSHBYTES_20 1521f36ad6ffea107b9925571e1566a8ddfadb73 OP_EQUAL),
                            },
                        ],
                    },
                ),
                witness_utxo: Some(
                    TxOut {
                        value: 500000000 SAT,
                        script_pubkey: Script(OP_0 OP_PUSHBYTES_20 bdb379b0229ac35d5edb234f7bdf792584a93450),
                    },
                ),
                partial_sigs: {},
                sighash_type: None,
                redeem_script: None,
                witness_script: None,
                bip32_derivation: {},
                final_script_sig: None,
                final_script_witness: None,
                ripemd160_preimages: {},
                sha256_preimages: {},
                hash160_preimages: {},
                hash256_preimages: {},
                tap_key_sig: None,
                tap_script_sigs: {},
                tap_scripts: {},
                tap_key_origins: {},
                tap_internal_key: None,
                tap_merkle_root: None,
                proprietary: {},
                unknown: {},
            },
        ],
        outputs: [
            Output {
                redeem_script: None,
                witness_script: None,
                bip32_derivation: {},
                tap_internal_key: None,
                tap_tree: None,
                tap_key_origins: {},
                proprietary: {},
                unknown: {},
            },
            Output {
                redeem_script: None,
                witness_script: None,
                bip32_derivation: {
                    PublicKey(
                        2f18d4094aa61432032ef0b1bd94d8dc2b25f92b592f605f07ff547256c90088dde9b7a29b8f822eeae49e755b97c0ccc1a48ff14276d944a837be19ef9b2ebd,
                    ): (
                        0xb197883f,
                        84'/1'/0'/0/1,
                    ),
                },
                tap_internal_key: None,
                tap_tree: None,
                tap_key_origins: {},
                proprietary: {},
                unknown: {},
            },
        ],
    },
)


successes:
    send::test::test_receiver_bbmobile_psbt

test result: ok. 1 passed; 0 failed; 0 ignored; 0 measured; 33 filtered out; finished in 0.00s

 *  Terminal will be reused by tasks, press any key to close it. 
