# EXAMPLE Output
                                                                                         
*  Executing task: cargo test --package payjoin --lib --features send --features receive --features _danger-local-https --features v2 --features io -- send::test::test_receiver_example_psbt --exact --show-output 

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

warning: `payjoin` (lib test) generated 4 warnings (run `cargo fix --lib -p payjoin --tests` to apply 1 suggestion)
    Finished `test` profile [unoptimized + debuginfo] target(s) in 1.40s
     Running unittests src/lib.rs (target/debug/deps/payjoin-f98f70e0cf2645d0)

running 1 test
test send::test::test_receiver_example_psbt ... ok

successes:

---- send::test::test_receiver_example_psbt stdout ----
[payjoin/src/send/mod.rs:1028:9] ":#?}" = ":#?}"
[payjoin/src/send/mod.rs:1028:9] before = Ok(
    Psbt {
        unsigned_tx: Transaction {
            version: Version(
                1,
            ),
            lock_time: 1691349 blocks,
            input: [
                TxIn {
                    previous_output: OutPoint {
                        txid: 78333a6f690071d6bddfe2a7d0992a33e44b68a552205f07b9d8960ae537685b,
                        vout: 0,
                    },
                    script_sig: Script(),
                    sequence: Sequence(0xfffffffe),
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
                        txid: a814562301e756da1708ee19fa3298c6b8754f435f82e9873f66a7bb982018e9,
                        vout: 1,
                    },
                    script_sig: Script(),
                    sequence: Sequence(0xfffffffe),
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
                    value: 367068 SAT,
                    script_pubkey: Script(OP_PUSHNUM_1 OP_PUSHBYTES_32 f934db05e19f802c995ee81d4965038300619d0166635c1d75bda2526cf89ac7),
                },
                TxOut {
                    value: 244852 SAT,
                    script_pubkey: Script(OP_PUSHNUM_1 OP_PUSHBYTES_32 ab330e4e98e034ad141b6d9f317157db0244f97fdcd298f0b3015faa50a74ab4),
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
                        value: 144852 SAT,
                        script_pubkey: Script(OP_PUSHNUM_1 OP_PUSHBYTES_32 62d5f24266a29545866e6cc370cd70649f8c75c02b69daca2ac0e02ecbb15e19),
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
                non_witness_utxo: None,
                witness_utxo: Some(
                    TxOut {
                        value: 469126 SAT,
                        script_pubkey: Script(OP_PUSHNUM_1 OP_PUSHBYTES_32 73acc698f272b1591fe305bf86dcbaa32f655384477a10503f1ec89aaaef6bb4),
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
[payjoin/src/send/mod.rs:1030:9] "{:#?}" = "{:#?}"
[payjoin/src/send/mod.rs:1030:9] after = Ok(
    Psbt {
        unsigned_tx: Transaction {
            version: Version(
                1,
            ),
            lock_time: 1691349 blocks,
            input: [
                TxIn {
                    previous_output: OutPoint {
                        txid: 78333a6f690071d6bddfe2a7d0992a33e44b68a552205f07b9d8960ae537685b,
                        vout: 0,
                    },
                    script_sig: Script(),
                    sequence: Sequence(0xfffffffe),
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
                        txid: a814562301e756da1708ee19fa3298c6b8754f435f82e9873f66a7bb982018e9,
                        vout: 1,
                    },
                    script_sig: Script(),
                    sequence: Sequence(0xfffffffe),
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
                    value: 367068 SAT,
                    script_pubkey: Script(OP_PUSHNUM_1 OP_PUSHBYTES_32 f934db05e19f802c995ee81d4965038300619d0166635c1d75bda2526cf89ac7),
                },
                TxOut {
                    value: 244852 SAT,
                    script_pubkey: Script(OP_PUSHNUM_1 OP_PUSHBYTES_32 ab330e4e98e034ad141b6d9f317157db0244f97fdcd298f0b3015faa50a74ab4),
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
                        value: 144852 SAT,
                        script_pubkey: Script(OP_PUSHNUM_1 OP_PUSHBYTES_32 62d5f24266a29545866e6cc370cd70649f8c75c02b69daca2ac0e02ecbb15e19),
                    },
                ),
                partial_sigs: {},
                sighash_type: None,
                redeem_script: None,
                witness_script: None,
                bip32_derivation: {},
                final_script_sig: Some(
                    Script(),
                ),
                final_script_witness: Some(
                    Witness: {
                        indices: 1,
                        indices_start: 65,
                        witnesses: [
                            [0x08, 0xb1, 0xbb, 0x2d, 0xc7, 0xc6, 0xb4, 0x0f, 0x25, 0x54, 0xcb, 0x41, 0x7b, 0xaa, 0x67, 0x8e, 0x6b, 0xce, 0x06, 0x9e, 0x01, 0x49, 0xdc, 0xca, 0xbb, 0x01, 0xcc, 0x65, 0xdd, 0xa0, 0x15, 0xa8, 0x4c, 0xc2, 0xe5, 0x9f, 0x1b, 0xd4, 0x93, 0x4e, 0xb0, 0xad, 0x7b, 0x9d, 0x1b, 0x47, 0x6f, 0x5f, 0x39, 0x77, 0xf3, 0x32, 0xd0, 0xa3, 0x94, 0x72, 0xa2, 0xd6, 0x90, 0x42, 0x6f, 0x9f, 0x8a, 0xd8],
                        ],
                    }
                    ,
                ),
                ripemd160_preimages: {},
                sha256_preimages: {},
                hash160_preimages: {},
                hash256_preimages: {},
                tap_key_sig: Some(
                    Signature {
                        signature: Signature(08b1bb2dc7c6b40f2554cb417baa678e6bce069e0149dccabb01cc65dda015a84cc2e59f1bd4934eb0ad7b9d1b476f5f3977f332d0a39472a2d690426f9f8ad8),
                        sighash_type: Default,
                    },
                ),
                tap_script_sigs: {},
                tap_scripts: {},
                tap_key_origins: {
                    XOnlyPublicKey(
                        60adfee35cb1a038188759ae5263331a16c9d22a5bfc3f17b62294e10e51fdf15e8cc2245fd506a27cb7242afc8ed6538633c91c2796b16c8ca7dfab164d4158,
                    ): (
                        [],
                        (
                            0xfceb2cea,
                            86'/1'/0'/1/1,
                        ),
                    ),
                },
                tap_internal_key: Some(
                    XOnlyPublicKey(
                        60adfee35cb1a038188759ae5263331a16c9d22a5bfc3f17b62294e10e51fdf15e8cc2245fd506a27cb7242afc8ed6538633c91c2796b16c8ca7dfab164d4158,
                    ),
                ),
                tap_merkle_root: None,
                proprietary: {},
                unknown: {},
            },
            Input {
                non_witness_utxo: None,
                witness_utxo: Some(
                    TxOut {
                        value: 469126 SAT,
                        script_pubkey: Script(OP_PUSHNUM_1 OP_PUSHBYTES_32 73acc698f272b1591fe305bf86dcbaa32f655384477a10503f1ec89aaaef6bb4),
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
                tap_internal_key: Some(
                    XOnlyPublicKey(
                        2e882c4f5ab76c52290189bb0d72988a29e067f55d95214b58cdf67a573a3687cabb814139139052bc6f91d45b7c57a0a6b3dcd7cc4ccd7c7df49ca10ff38bea,
                    ),
                ),
                tap_tree: None,
                tap_key_origins: {
                    XOnlyPublicKey(
                        2e882c4f5ab76c52290189bb0d72988a29e067f55d95214b58cdf67a573a3687cabb814139139052bc6f91d45b7c57a0a6b3dcd7cc4ccd7c7df49ca10ff38bea,
                    ): (
                        [],
                        (
                            0xfceb2cea,
                            86'/1'/0'/0/5,
                        ),
                    ),
                },
                proprietary: {},
                unknown: {},
            },
        ],
    },
)


successes:
    send::test::test_receiver_example_psbt

test result: ok. 1 passed; 0 failed; 0 ignored; 0 measured; 32 filtered out; finished in 0.00s

 *  Terminal will be reused by tasks, press any key to close it. 
