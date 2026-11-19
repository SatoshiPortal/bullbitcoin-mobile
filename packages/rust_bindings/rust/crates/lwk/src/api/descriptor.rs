use lwk_signer::SwSigner;
use zeroize::Zeroizing;

// use crate::frb_generated::RustOpaque;

use super::{error::LwkError, types::LiquidNetwork};

/// Wallet descriptor class used to create a new wallet
#[derive(Debug)]
pub struct Descriptor {
    pub ct_descriptor: String,
}
impl Descriptor {
    /// Createa new wpkh confidential descriptor based on Slip77 blinding key derivation
    pub fn new_confidential(
        network: LiquidNetwork,
        mnemonic: String,
    ) -> Result<Descriptor, LwkError> {
        let mnemonic = Zeroizing::new(mnemonic);
        let signer: SwSigner = SwSigner::new_with_network(&mnemonic, network.into())?.into();
        Self::from_signer(&signer)
    }

    /// Create a new wpkh confidential descriptor based on Slip77 blinding key derivation,
    /// from a 64-byte BIP39 seed instead of English mnemonic words.
    ///
    /// The seed encodes the mnemonic language and passphrase, which `new_confidential` cannot
    /// carry. An English mnemonic without passphrase gives the same descriptor through both.
    pub fn new_confidential_from_seed(
        network: LiquidNetwork,
        seed: Vec<u8>,
    ) -> Result<Descriptor, LwkError> {
        let seed = Zeroizing::new(seed);
        let seed_bytes: &[u8; 64] = seed.as_slice().try_into().map_err(|_| LwkError {
            msg: format!("seed is {} bytes, a BIP39 seed is 64 bytes", seed.len()),
        })?;
        let signer = SwSigner::from_seed_with_network(seed_bytes, network.into())?;
        Self::from_signer(&signer)
    }

    fn from_signer(signer: &SwSigner) -> Result<Descriptor, LwkError> {
        let script_variant = lwk_common::Singlesig::Wpkh;
        let blinding_variant = lwk_common::DescriptorBlindingKey::Slip77;
        let desc_str = lwk_common::singlesig_desc(signer, script_variant, blinding_variant)?;
        Ok(Descriptor {
            ct_descriptor: desc_str.to_string(),
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::api::wallet::Wallet;

    const MNEMONIC: &str = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about";

    /// Key derivation must not move across LWK upgrades: these vectors were
    /// produced with lwk 0.18.1 and LWK master alike.
    #[test]
    fn keys_and_addresses_derive_as_before() {
        let cases = [
            (
                LiquidNetwork::Mainnet,
                "ct(slip77(9c8e4f05c7711a98c838be228bcb84924d4570ca53f35fa1c793e58841d47023),elwpkh([73c5da0a/84h/1776h/0h]xpub6CRFzUgHFDaiDAQFNX7VeV9JNPDRabq6NYSpzVZ8zW8ANUCiDdenkb1gBoEZuXNZb3wPc1SVcDXgD2ww5UBtTb8s8ArAbTkoRQ8qn34KgcY/<0;1>/*))#y8jljyxl",
                "lq1qqvxk052kf3qtkxmrakx50a9gc3smqad2ync54hzntjt980kfej9kkfe0247rp5h4yzmdftsahhw64uy8pzfe7cpg4fgykm7cv",
            ),
            (
                LiquidNetwork::Testnet,
                "ct(slip77(9c8e4f05c7711a98c838be228bcb84924d4570ca53f35fa1c793e58841d47023),elwpkh([73c5da0a/84h/1h/0h]tpubDC8msFGeGuwnKG9Upg7DM2b4DaRqg3CUZa5g8v2SRQ6K4NSkxUgd7HsL2XVWbVm39yBA4LAxysQAm397zwQSQoQgewGiYZqrA9DsP4zbQ1M/<0;1>/*))#xte2lx9x",
                "tlq1qq2xvpcvfup5j8zscjq05u2wxxjcyewk7979f3mmz5l7uw5pqmx6xf5xy50hsn6vhkm5euwt72x878eq6zxx2z58hd7zrsg9qn",
            ),
        ];
        for (network, expected_descriptor, expected_address) in cases {
            let descriptor = Descriptor::new_confidential(network, MNEMONIC.to_string()).unwrap();
            assert_eq!(descriptor.ct_descriptor, expected_descriptor);

            let dbpath = std::env::temp_dir()
                .join(format!("lwk_derivation_{network:?}_{}", std::process::id()));
            let wallet = Wallet::init(
                network,
                dbpath.to_string_lossy().into_owned(),
                descriptor,
                None,
            )
            .unwrap();
            assert_eq!(wallet.address(0).unwrap().confidential, expected_address);
            let _ = std::fs::remove_dir_all(dbpath);
        }
    }

    use bip39::{Language, Mnemonic};

    const ABANDON_MNEMONIC: &str = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about";

    // Expected descriptors computed outside lwk and outside this crate, by a standalone Python
    // script using only the standard library: BIP39 seed by PBKDF2-HMAC-SHA512 over the NFKD
    // mnemonic, BIP32 master key and hardened derivation of m/84'/1776'/0' with its own
    // secp256k1 arithmetic, SLIP77 master blinding key by SLIP-0021 HMACs from the seed, and
    // the BIP380 descriptor checksum. The same script reproduces the "abandon ... about"
    // descriptor that `new_confidential` returns, on mainnet and testnet.
    const TREZOR_MAINNET_DESCRIPTOR: &str = "ct(slip77(e974a8dfcbd463d5d7f934fa35916ab1edd15ad5b4d1a9dde4bd89eec0bcc872),elwpkh([b4e3f5ed/84h/1776h/0h]xpub6CzUJ282mBSqDR69LkEEFWr11oY6gcy47Mt6Hfoeb2Tgzq8AN6asRYv9LjwC6f9a6pDqswqHdtnJmuniNqDP7ZgBoPqy55az9tGUHk4KPoc/<0;1>/*))#xvqkzrvl";
    const JAPANESE_MAINNET_DESCRIPTOR: &str = "ct(slip77(45ca5d9811bccd804a5b51aaf262a6b5be46f0fee838fcc5d1451b3c23944f54),elwpkh([d9a4c6ac/84h/1776h/0h]xpub6CxzR79MsXkn6uYBAQXiFxPxHLCTkLSgjfi2GrYkAo2NgUY3KCh3a6tgMnJMNV7ZdUvpLV2Dsp4nB5t3rFhNbGExFBb5euGVcqhKZkPx9PF/<0;1>/*))#2q0d70qc";

    fn seed(language: Language, entropy: &[u8], passphrase: &str) -> Vec<u8> {
        Mnemonic::from_entropy_in(language, entropy)
            .unwrap()
            .to_seed(passphrase)
            .to_vec()
    }

    #[test]
    fn seed_of_an_english_mnemonic_gives_the_mnemonic_descriptor() {
        let english = seed(Language::English, &[0u8; 16], "");
        for network in [LiquidNetwork::Mainnet, LiquidNetwork::Testnet] {
            let from_mnemonic =
                Descriptor::new_confidential(network, ABANDON_MNEMONIC.to_owned()).unwrap();
            let from_seed =
                Descriptor::new_confidential_from_seed(network, english.clone()).unwrap();
            assert_eq!(from_seed.ct_descriptor, from_mnemonic.ct_descriptor);
        }
    }

    #[test]
    fn passphrase_seed_gives_the_expected_descriptor() {
        let network = LiquidNetwork::Mainnet;
        // BIP39 reference vector: entropy 00..00, passphrase "TREZOR".
        let with_passphrase = seed(Language::English, &[0u8; 16], "TREZOR");
        assert_eq!(
            hex::encode(&with_passphrase),
            "c55257c360c07c72029aebc1b53c05ed0362ada38ead3e3e9efa3708e53495531f09a6987599d18264c1e1c92f2cf141630c7a3c4ab7c81b2f001698e7463b04"
        );
        let from_passphrase =
            Descriptor::new_confidential_from_seed(network, with_passphrase).unwrap();
        assert_eq!(from_passphrase.ct_descriptor, TREZOR_MAINNET_DESCRIPTOR);
        let from_mnemonic =
            Descriptor::new_confidential(network, ABANDON_MNEMONIC.to_owned()).unwrap();
        assert_ne!(from_passphrase.ct_descriptor, from_mnemonic.ct_descriptor);
    }

    #[test]
    fn japanese_seed_gives_the_expected_descriptor() {
        let network = LiquidNetwork::Mainnet;
        // First vector of the Japanese BIP39 test vectors (github.com/bip32JP/bip32JP.github.io,
        // test_JP_BIP39.json): the same zero entropy as "abandon ... about".
        let mnemonic = Mnemonic::from_entropy_in(Language::Japanese, &[0u8; 16]).unwrap();
        let japanese = mnemonic.to_seed("㍍ガバヴァぱばぐゞちぢ十人十色");
        assert_eq!(
            hex::encode(japanese),
            "a262d6fb6122ecf45be09c50492b31f92e9beb7d9a845987a02cefda57a15f9c467a17872029a9e92299b5cbdf306e3a0ee620245cbd508959b6cb7ca637bd55"
        );

        let from_seed = Descriptor::new_confidential_from_seed(network, japanese.to_vec()).unwrap();
        assert_eq!(from_seed.ct_descriptor, JAPANESE_MAINNET_DESCRIPTOR);
    }

    #[test]
    fn rejects_a_seed_of_invalid_length() {
        for len in [0, 15, 16, 32, 63, 65] {
            let err =
                Descriptor::new_confidential_from_seed(LiquidNetwork::Mainnet, vec![0u8; len])
                    .unwrap_err();
            assert!(err.msg.contains("a BIP39 seed is 64 bytes"), "{}", err.msg);
        }
    }

    #[test]
    fn regtest_uses_the_testnet_descriptor() {
        // Elements regtest, like lwk, uses testnet keys: tpub and coin type 1.
        let regtest =
            Descriptor::new_confidential(LiquidNetwork::Regtest, ABANDON_MNEMONIC.to_owned())
                .unwrap();
        let testnet =
            Descriptor::new_confidential(LiquidNetwork::Testnet, ABANDON_MNEMONIC.to_owned())
                .unwrap();
        assert_eq!(regtest.ct_descriptor, testnet.ct_descriptor);
        assert_eq!(
            regtest.ct_descriptor,
            "ct(slip77(9c8e4f05c7711a98c838be228bcb84924d4570ca53f35fa1c793e58841d47023),elwpkh([73c5da0a/84h/1h/0h]tpubDC8msFGeGuwnKG9Upg7DM2b4DaRqg3CUZa5g8v2SRQ6K4NSkxUgd7HsL2XVWbVm39yBA4LAxysQAm397zwQSQoQgewGiYZqrA9DsP4zbQ1M/<0;1>/*))#xte2lx9x"
        );
    }
}
