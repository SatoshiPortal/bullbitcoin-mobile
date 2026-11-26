use lwk_common::{FeeRate, Signer};
use lwk_signer::SwSigner;
use lwk_wollet::blocking::BlockchainBackend;
// use lwk_wollet::elements_miniscript::descriptor;
use flutter_rust_bridge::RustOpaqueNom as RustOpaque;
// use log::{info, warn};
use lwk_wollet::elements::{
    pset::PartiallySignedTransaction, Address as LwkAddress, AssetId as LwkAssetId,
    OutPoint as LwkOutPoint, Txid as LwkTxid,
};
use lwk_wollet::AddressResult;
use lwk_wollet::WolletDescriptor;
use std::str::FromStr;
pub use std::sync::Mutex;
use std::sync::MutexGuard;
use zeroize::Zeroizing;

use super::descriptor::Descriptor;
use super::error::LwkError;
use super::types::Address;
use super::types::AssetIdBTreeMapUInt;
use super::types::LiquidNetwork;
use super::types::OutPoint;
use super::types::PsetAmounts;
use super::types::Tx;
use super::types::TxOut;
use super::types::TxOutputSpec;
use super::types::WalletBalances;

/// Upper sanity bound on the fee rate, in sats/kvB: 100 sat/vB.
///
/// Liquid fees sit around 0.1 sat/vB, so this is three orders of magnitude of
/// headroom. It exists to stop a fat-fingered or unit-confused value, not to
/// express policy.
pub const MAX_FEE_RATE_SATS_PER_KVB: f32 = 100_000.0;

/// Reject a fee rate that cannot mean what the caller intended.
///
/// The unit here is sats/**kvB**, not sat/vB: 1 sat/vB is 1000.0. Nothing in
/// the old signature said so, and the values lwk derives from a bad one are
/// silent rather than loud — on a 2500 WU confidential transaction, `f32::NAN`
/// and `-5.0` both produce a 0 sat fee, and `f32::INFINITY` produces a fee of
/// `u64::MAX`. A caller assuming sat/vB and passing `1.0` gets 0.001 sat/vB,
/// under Liquid's relay floor, so the transaction never confirms and the coins
/// stay locked in an unconfirmed spend.
///
/// Returns the rate as the `FeeRate` lwk's transaction builder takes.
fn validate_fee_rate(fee_rate: f32) -> anyhow::Result<FeeRate, LwkError> {
    if !fee_rate.is_finite() {
        return Err(LwkError {
            msg: format!("Fee rate must be a finite number, got {fee_rate}"),
        });
    }
    if fee_rate <= 0.0 {
        return Err(LwkError {
            msg: format!("Fee rate must be positive, got {fee_rate} sats/kvB"),
        });
    }
    if fee_rate > MAX_FEE_RATE_SATS_PER_KVB {
        return Err(LwkError {
            msg: format!(
                "Fee rate {fee_rate} sats/kvB exceeds the {MAX_FEE_RATE_SATS_PER_KVB} \
                 sats/kvB bound; note the unit is sats/kvB, so 1 sat/vB is 1000.0"
            ),
        });
    }
    // Unreachable after the checks above, which are stricter than lwk's own.
    FeeRate::from_sat_kvb(fee_rate).ok_or_else(|| LwkError {
        msg: format!("Fee rate {fee_rate} sats/kvB is not accepted by lwk"),
    })
}

/// Validate a destination address the way lwk validates a normal recipient.
///
/// `LwkAddress::from_str` accepts an address for any network and says nothing
/// about confidentiality. lwk_wollet 0.18's `TxBuilder::drain_lbtc_to` took the
/// address without validating it, so a drain accepted a mainnet address on a
/// testnet wallet, and an unblinded address that leaks the amount and recipient
/// of the whole sweep. `drain_lbtc_to` now validates too; this check is kept so
/// both paths fail early, before any builder call, with the same message.
///
/// Mirrors lwk_wollet's `validate_address`: parse under the wallet's own
/// address params, then require a blinding key.
fn validate_out_address(
    address: &str,
    network: lwk_wollet::Network,
) -> anyhow::Result<LwkAddress, LwkError> {
    let address = LwkAddress::parse_with_params(address, network.address_params())
        .map_err(|e| LwkError {
            msg: format!("Invalid address for {:?}: {}", network, e),
        })?;
    if address.blinding_pubkey.is_none() {
        return Err(LwkError {
            msg: "Address is not confidential".to_string(),
        });
    }
    Ok(address)
}

/// Main wallet object
pub struct Wallet {
    pub(crate) inner: RustOpaque<Mutex<lwk_wollet::Wollet>>,
}

/// UTXO count above which consolidation is offered
pub const HIGH_UTXO_THRESHOLD: u32 = 125;
/// Max inputs per consolidation tx (safety margin under the 256 hard limit)
pub const MAXIMUM_INPUTS: u32 = 250;

/// Compute the number of consolidation batches and how many UTXOs go in each,
/// so that no batch exceeds `max_inputs` and batches are as evenly sized as
/// possible.
///
/// Returns `(number_of_batches, utxos_per_batch)`.
fn batch_sizes(total: usize, max_inputs: usize) -> (usize, usize) {
    let n = total.div_ceil(max_inputs);
    (n, total.div_ceil(n))
}

impl Wallet {
    /// Used internally to create a lock on the wallet while being used.
    fn get_wallet(&self) -> Result<MutexGuard<lwk_wollet::Wollet>, LwkError> {
        {
            match self.inner.lock() {
                Ok(result) => Ok(result),
                Err(_) => Err(LwkError {
                    msg: "Could not aquire lock on wallet".to_string(),
                }),
            }
        }
    }

    /// Initializes a wallet from a specific db path and descriptor
    ///
    /// The policy asset id is only for the regtest network, whose node may use another policy
    /// asset than lwk's default; mainnet and testnet reject it.
    pub fn init(
        network: LiquidNetwork,
        dbpath: String,
        descriptor: Descriptor,
        policy_asset: Option<String>,
    ) -> anyhow::Result<Wallet, LwkError> {
        let network = network.elements_network(policy_asset)?;
        let desc_str = descriptor.ct_descriptor;
        let descriptor = WolletDescriptor::from_str(&desc_str)?;
        let wollet = lwk_wollet::WolletBuilder::new(network, descriptor)
            .with_legacy_fs_store(dbpath.clone())?
            .build()?;
        let opaque = RustOpaque::new(Mutex::new(wollet));
        let wallet = Wallet { inner: opaque };
        Ok(wallet)
    }

    /// Syncs the wallet db with its latest state fetched from the electrum server
    /// Returns true if an LWK update was applied, false if the scan found no changes.
    /// Tip-only changes count as updates. Scan and persistence errors are propagated.
    /// Using None for stop_at_index will sync normally with a stop gap of 20
    ///
    /// ⚠️ `validate_domain` is ignored and kept only for API compatibility:
    /// validation is always on for Liquid. The TLS certificate must be valid
    /// for the server's domain name, so a self-signed or IP-addressed server
    /// is rejected.
    /// The connection uses TLS, except for a `tcp://` URL on a regtest wallet.
    pub fn sync(
        &self,
        electrum_url: String,
        validate_domain: bool,
        stop_at_index: Option<u32>,
        timeout: Option<u8>,
    ) -> anyhow::Result<bool, LwkError> {
        super::ensure_crypto_provider();
        // ⚠️ Dropped here: `ElectrumClientBuilder` parses the URL and derives
        // domain validation from it, always on for `ssl://` with a domain name.
        // Kept in the signature so the Dart API does not break.
        let _ = validate_domain;
        let network = LiquidNetwork::from(self.get_wallet()?.network());
        let mut electrum_client =
            super::blockchain::electrum_client(network, &electrum_url, timeout)?;
        let mut wallet = self.get_wallet()?;
        match electrum_client.full_scan_to_index(&*wallet, stop_at_index.unwrap_or(0))? {
            Some(update) => {
                wallet.apply_update(update)?;
                Ok(true)
            }
            None => Ok(false),
        }
    }

    /// Get the descriptor string for the wallet
    pub fn descriptor(&self) -> anyhow::Result<String, LwkError> {
        Ok(self.get_wallet()?.descriptor()?.to_string())
    }

    /// Get the blinding key string for the wallet
    pub fn blinding_key(&self) -> anyhow::Result<String, LwkError> {
        Ok(self.get_wallet()?.descriptor()?.key.to_string())
    }

    /// Get the last unused address from the wallet
    pub fn address_last_unused(&self) -> anyhow::Result<Address, LwkError> {
        let address: AddressResult = self.get_wallet()?.address(None)?.into();
        Ok(address.into())
    }

    /// Get an address from a specific index
    pub fn address(&self, index: u32) -> anyhow::Result<Address, LwkError> {
        let address: AddressResult = self.get_wallet()?.address(Some(index))?.into();
        Ok(address.into())
    }

    /// Get balances for a wallet.
    pub fn balances(&self) -> anyhow::Result<WalletBalances, LwkError> {
        let balance_map: AssetIdBTreeMapUInt = self.get_wallet()?.balance()?.as_ref().clone().into();
        let balance = WalletBalances::from(balance_map);
        Ok(balance)
    }

    /// Get the transaction history of the wallet
    pub fn txs(&self) -> anyhow::Result<Vec<Tx>, LwkError> {
        let txs = self
            .get_wallet()?
            .transactions()?
            .iter()
            .map(|x| Tx::from(x.to_owned()))
            .collect();
        Ok(txs)
    }

    /// Build a LBTC transaction
    pub fn build_lbtc_tx(
        &self,
        sats: u64,
        out_address: String,
        fee_rate: f32,
        drain: bool,
    ) -> anyhow::Result<String, LwkError> {
        let lwk_fee_rate = validate_fee_rate(fee_rate)?;
        let wallet = self.get_wallet()?;
        let network = wallet.network();
        let tx_builder = wallet.tx_builder();
        // Validated for both branches: the drain path never validated at all,
        // and validating up front gives the same rejection a clearer message on
        // the recipient path.
        let address = validate_out_address(&out_address, network)?;
        if drain {
            let pset = tx_builder
                .drain_lbtc_wallet()
                .drain_lbtc_to(&address)?
                .enable_ct_discount()
                .fee_rate(Some(lwk_fee_rate))
                .finish()?;
            Ok(pset.to_string())
        } else {
            let pset = tx_builder
                .add_lbtc_recipient(&address, sats)?
                .enable_ct_discount()
                .fee_rate(Some(lwk_fee_rate))
                .finish()?;
            Ok(pset.to_string())
        }
    }
    /// Build N unsigned PSETs that consolidate the wallet's confirmed L-BTC UTXOs.
    ///
    /// Each PSET sweeps up to `maximum_inputs` coins into a single output, sent to
    /// a fresh unused address (a different address is used for each batch).
    /// Returns an empty vec if the UTXO count is <= `high_utxo_threshold`.
    ///
    /// Batches whose value doesn't cover the fee (dust batches) are skipped. If
    /// every batch is dust, an error is returned.
    pub fn consolidate(
        &self,
        fee_rate: f32,
        high_utxo_threshold: Option<u32>,
        maximum_inputs: Option<u32>,
    ) -> anyhow::Result<Vec<String>, LwkError> {
        let lwk_fee_rate = validate_fee_rate(fee_rate)?;
        let wallet = self.get_wallet()?;
        let policy_asset = wallet.policy_asset();

        let threshold = high_utxo_threshold.unwrap_or(HIGH_UTXO_THRESHOLD);
        let mi = maximum_inputs.unwrap_or(MAXIMUM_INPUTS).min(MAXIMUM_INPUTS) as usize;
        if mi == 0 {
            return Err(LwkError {
                msg: "maximum_inputs must be greater than 0".to_string(),
            });
        }

        let utxos: Vec<_> = wallet
            .utxos()?
            .into_iter()
            .filter(|u| u.unblinded.asset == policy_asset && u.height.is_some())
            .collect();

        let total = utxos.len();
        if total <= threshold as usize {
            return Ok(vec![]);
        }

        let (n, per_batch) = batch_sizes(total, mi);

        let start_index = wallet.address(None)?.index();

        let mut psets = Vec::with_capacity(n);
        for (i, chunk) in utxos.chunks(per_batch).enumerate() {
            let address = wallet
                .address(Some(start_index + i as u32))?
                .address()
                .clone();
            let outpoints: Vec<_> = chunk.iter().map(|u| u.outpoint).collect();
            match wallet
                .tx_builder()
                .set_wallet_utxos(outpoints)
                .drain_lbtc_to(&address)?
                .enable_ct_discount()
                .fee_rate(Some(lwk_fee_rate))
                .finish()
            {
                Ok(pset) => psets.push(pset.to_string()),
                Err(lwk_wollet::Error::InsufficientFunds { .. }) => continue, // dust batch
                Err(e) => return Err(e.into()),
            }
        }

        if psets.is_empty() {
            return Err(LwkError {
                msg: format!(
                    "consolidation: all {n} batches are dust (batch value <= fee at {fee_rate} sat/vb)"
                ),
            });
        }

        Ok(psets)
    }

    /// Build a PSET spending `utxos`, paying `outputs`, with any leftover
    /// L-BTC swept to `drain_to` if set.
    ///
    /// General-purpose builder for custom output shapes
    pub fn build_custom_tx(
        &self,
        utxos: Vec<OutPoint>,
        outputs: Vec<TxOutputSpec>,
        drain_to: Option<String>,
        fee_rate: f32,
    ) -> anyhow::Result<String, LwkError> {
        let lwk_fee_rate = validate_fee_rate(fee_rate)?;
        let wallet = self.get_wallet()?;

        let outpoints: Vec<LwkOutPoint> = utxos
            .into_iter()
            .map(|o| -> anyhow::Result<LwkOutPoint, LwkError> {
                let txid = LwkTxid::from_str(&o.txid)?;
                Ok(LwkOutPoint::new(txid, o.vout))
            })
            .collect::<Result<_, _>>()?;

        let mut builder = wallet.tx_builder().set_wallet_utxos(outpoints);

        for out in outputs {
            let address = LwkAddress::from_str(&out.address)?;
            builder = match out.asset_id {
                None => builder.add_lbtc_recipient(&address, out.satoshi)?,
                Some(asset) => {
                    let asset_id = match LwkAssetId::from_str(&asset) {
                        Ok(result) => result,
                        Err(_) => {
                            return Err(LwkError {
                                msg: "Invalid asset".to_string(),
                            })
                        }
                    };
                    builder.add_recipient(&address, out.satoshi, asset_id)?
                }
            };
        }

        if let Some(drain_addr) = drain_to {
            // `drain_lbtc_wallet()` sets a flag (`drain_lbtc`) that
            // `lwk_wollet`'s TxBuilder::finish never reads (still true on LWK
            // master) — dead regardless of manual UTXO selection.
            // `drain_lbtc_to` alone is what actually directs leftover L-BTC to
            // `address`. It validates the address since LWK 0.19; the explicit
            // check below keeps the error message unchanged.
            let address = validate_out_address(&drain_addr, wallet.network())?;
            builder = builder.drain_lbtc_to(&address)?;
        }

        let pset = builder
            .enable_ct_discount()
            .fee_rate(Some(lwk_fee_rate))
            .finish()?;
        Ok(pset.to_string())
    }

    /// Build a transaction for a specific asset
    pub fn build_asset_tx(
        &self,
        sats: u64,
        out_address: String,
        fee_rate: f32,
        asset: String,
    ) -> anyhow::Result<String, LwkError> {
        let lwk_fee_rate = validate_fee_rate(fee_rate)?;
        let wallet = self.get_wallet()?;
        let tx_builder = wallet.tx_builder();
        let address = LwkAddress::from_str(&out_address)?;
        let asset = match LwkAssetId::from_str(&asset) {
            Ok(result) => result,
            Err(_) => {
                return Err(LwkError {
                    msg: "Invalid asset".to_string(),
                })
            }
        };
        let pset = tx_builder
            .add_recipient(&address, sats, asset)?
            .enable_ct_discount()
            .fee_rate(Some(lwk_fee_rate))
            .finish()?;
        Ok(pset.to_string())
    }

    /// Decode a transaction given a PSET
    pub fn decode_tx(&self, pset: String) -> anyhow::Result<PsetAmounts, LwkError> {
        let mut pset = PartiallySignedTransaction::from_str(&pset)?;
        let wallet = self.get_wallet()?;
        let pset_details = wallet.get_details(&mut pset)?;
        let policy_asset = wallet.policy_asset();
        Ok(PsetAmounts::from_balance(
            pset_details.balance(),
            &policy_asset,
        ))
    }

    fn sign_tx_common(
        &self,
        network: LiquidNetwork,
        pset: String,
        mnemonic: String,
        add_details: bool,
    ) -> anyhow::Result<String, LwkError> {
        let mnemonic = Zeroizing::new(mnemonic);
        let signer: SwSigner = SwSigner::new_with_network(&mnemonic, network.into())?;
        self.sign_and_finalize(&signer, pset, add_details)
    }

    fn sign_tx_with_seed_common(
        &self,
        network: LiquidNetwork,
        pset: String,
        seed: Vec<u8>,
        add_details: bool,
    ) -> anyhow::Result<String, LwkError> {
        let seed = Zeroizing::new(seed);
        let seed_bytes: &[u8; 64] = seed.as_slice().try_into().map_err(|_| LwkError {
            msg: format!("seed is {} bytes, a BIP39 seed is 64 bytes", seed.len()),
        })?;
        let signer = SwSigner::from_seed_with_network(seed_bytes, network.into())?;
        self.sign_and_finalize(&signer, pset, add_details)
    }

    fn sign_and_finalize(
        &self,
        signer: &SwSigner,
        pset: String,
        add_details: bool,
    ) -> anyhow::Result<String, LwkError> {
        let mut pset = PartiallySignedTransaction::from_str(&pset)?;
        if add_details {
            self.get_wallet()?.add_details(&mut pset)?;
        }
        // Do not report success when this key added no signature, including an already-signed PSET.
        if signer.sign(&mut pset)? == 0 {
            return Err(LwkError {
                msg: "the signer added no signature: its key owns no unsigned input of this PSET"
                    .to_owned(),
            });
        }
        let tx = self.get_wallet()?.finalize(&mut pset)?;
        let finalized_pset = PartiallySignedTransaction::from_tx(tx.clone());
        Ok(finalized_pset.to_string())
    }

    /// Sign a wallet transaction, returns (pset, signed_bytes)
    pub fn sign_tx(
        &self,
        network: LiquidNetwork,
        pset: String,
        mnemonic: String,
    ) -> anyhow::Result<String, LwkError> {
        self.sign_tx_common(network, pset, mnemonic, false)
    }

    /// Sign a wallet transaction with a 64-byte BIP39 seed instead of mnemonic words
    pub fn sign_tx_with_seed(
        &self,
        network: LiquidNetwork,
        pset: String,
        seed: Vec<u8>,
    ) -> anyhow::Result<String, LwkError> {
        self.sign_tx_with_seed_common(network, pset, seed, false)
    }

    /// Get the policy asset (L-BTC) id of the wallet's network
    pub fn policy_asset(&self) -> anyhow::Result<String, LwkError> {
        Ok(self.get_wallet()?.policy_asset().to_string())
    }

    /// Get utxos of the wallet
    pub fn utxos(&self) -> anyhow::Result<Vec<TxOut>, LwkError> {
        let wallet_tx_outs = self.get_wallet()?.utxos()?;
        let tx_outs = wallet_tx_outs.into_iter().map(TxOut::from).collect();
        Ok(tx_outs)
    }

    /// Sign a pset with extra details (used for asset transactions)
    pub fn signed_pset_with_extra_details(
        &self,
        network: LiquidNetwork,
        pset: String,
        mnemonic: String,
    ) -> anyhow::Result<String, LwkError> {
        self.sign_tx_common(network, pset, mnemonic, true)
    }

    /// Sign a pset with extra details with a 64-byte BIP39 seed instead of mnemonic words
    pub fn signed_pset_with_extra_details_with_seed(
        &self,
        network: LiquidNetwork,
        pset: String,
        seed: Vec<u8>,
    ) -> anyhow::Result<String, LwkError> {
        self.sign_tx_with_seed_common(network, pset, seed, true)
    }
}

#[cfg(test)]
mod tests {

    use crate::api::blockchain::Blockchain;

    use super::*;
    const ABANDON_MNEMONIC: &str = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about";

    fn abandon_seed() -> Vec<u8> {
        bip39::Mnemonic::parse_in(bip39::Language::English, ABANDON_MNEMONIC)
            .unwrap()
            .to_seed("")
            .to_vec()
    }

    /// A wallet persisted in its own temporary directory, removed when the wallet is dropped.
    struct OfflineWallet {
        wallet: Option<Wallet>,
        dbpath: std::path::PathBuf,
    }

    impl std::ops::Deref for OfflineWallet {
        type Target = Wallet;

        fn deref(&self) -> &Wallet {
            self.wallet.as_ref().expect("present until dropped")
        }
    }

    impl Drop for OfflineWallet {
        fn drop(&mut self) {
            // Close the wallet store before deleting its directory.
            drop(self.wallet.take());
            let _ = std::fs::remove_dir_all(&self.dbpath);
        }
    }

    fn offline_wallet(name: &str, descriptor: Descriptor) -> OfflineWallet {
        let dbpath = std::env::temp_dir().join(format!("lwk-dart-{name}-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&dbpath);
        let wallet = Wallet::init(
            LiquidNetwork::Testnet,
            dbpath.display().to_string(),
            descriptor,
            None,
        )
        .unwrap();
        OfflineWallet {
            wallet: Some(wallet),
            dbpath,
        }
    }

    /// One explicit input paying the wallet's first receive address, keyed for signing, and
    /// one explicit output back to that address. Built offline, no chain data needed.
    fn pset_spending_first_address(wallet: &Wallet) -> String {
        use lwk_wollet::bitcoin::bip32::DerivationPath;
        use lwk_wollet::elements::pset::{Input, Output};
        use lwk_wollet::elements::{confidential, OutPoint, TxOut as ElementsTxOut, TxOutWitness};

        let wollet = wallet.get_wallet().unwrap();
        let script = wollet.address(Some(0)).unwrap().address().script_pubkey();
        let asset = wollet.policy_asset();
        drop(wollet);

        let mnemonic_signer =
            SwSigner::new_with_network(ABANDON_MNEMONIC, LiquidNetwork::Testnet.into()).unwrap();
        let path = DerivationPath::from_str("m/84h/1h/0h/0/0").unwrap();
        let public_key = lwk_wollet::bitcoin::PublicKey::new(
            mnemonic_signer.derive_xpub(&path).unwrap().public_key,
        );

        let mut input = Input::from_prevout(
            OutPoint::from_str(
                "0000000000000000000000000000000000000000000000000000000000000001:0",
            )
            .unwrap(),
        );
        input.witness_utxo = Some(ElementsTxOut {
            asset: confidential::Asset::Explicit(asset),
            value: confidential::Value::Explicit(100_000),
            nonce: confidential::Nonce::Null,
            script_pubkey: script.clone(),
            witness: TxOutWitness::default(),
        });
        input
            .bip32_derivation
            .insert(public_key, (mnemonic_signer.fingerprint(), path));

        let mut pset = PartiallySignedTransaction::new_v2();
        pset.add_input(input);
        pset.add_output(Output::new_explicit(script, 99_000, asset, None));
        pset.add_output(Output::from_txout(ElementsTxOut::new_fee(1_000, asset)));
        pset.to_string()
    }

    #[test]
    fn signing_with_the_seed_matches_signing_with_the_mnemonic() {
        let network = LiquidNetwork::Testnet;
        let descriptor =
            Descriptor::new_confidential(network, ABANDON_MNEMONIC.to_owned()).unwrap();
        let wallet = offline_wallet("sign-seed", descriptor);
        let pset = pset_spending_first_address(&wallet);

        let with_mnemonic = wallet
            .sign_tx(network, pset.clone(), ABANDON_MNEMONIC.to_owned())
            .unwrap();
        let with_seed = wallet
            .sign_tx_with_seed(network, pset.clone(), abandon_seed())
            .unwrap();
        assert_ne!(with_mnemonic, pset, "the input must have been signed");
        assert_eq!(with_seed, with_mnemonic);

        let details_with_mnemonic = wallet
            .signed_pset_with_extra_details(network, pset.clone(), ABANDON_MNEMONIC.to_owned())
            .unwrap();
        let details_with_seed = wallet
            .signed_pset_with_extra_details_with_seed(network, pset, abandon_seed())
            .unwrap();
        assert_eq!(details_with_seed, details_with_mnemonic);
    }

    #[test]
    fn signing_with_a_key_that_owns_no_input_fails() {
        // BIP39 test vector unrelated to the wallet.
        const FOREIGN_MNEMONIC: &str =
            "legal winner thank year wave sausage worth useful legal winner thank yellow";
        let foreign_seed = bip39::Mnemonic::parse_in(bip39::Language::English, FOREIGN_MNEMONIC)
            .unwrap()
            .to_seed("")
            .to_vec();
        let network = LiquidNetwork::Testnet;
        let descriptor =
            Descriptor::new_confidential(network, ABANDON_MNEMONIC.to_owned()).unwrap();
        let wallet = offline_wallet("sign-foreign-key", descriptor);
        let pset = pset_spending_first_address(&wallet);

        let results = [
            (
                "sign_tx",
                wallet.sign_tx(network, pset.clone(), FOREIGN_MNEMONIC.to_owned()),
            ),
            (
                "signed_pset_with_extra_details",
                wallet.signed_pset_with_extra_details(
                    network,
                    pset.clone(),
                    FOREIGN_MNEMONIC.to_owned(),
                ),
            ),
            (
                "sign_tx_with_seed",
                wallet.sign_tx_with_seed(network, pset.clone(), foreign_seed.clone()),
            ),
            (
                "signed_pset_with_extra_details_with_seed",
                wallet.signed_pset_with_extra_details_with_seed(network, pset, foreign_seed),
            ),
        ];
        let accepted: Vec<&str> = results
            .iter()
            .filter(|(_, result)| result.is_ok())
            .map(|(name, _)| *name)
            .collect();
        assert!(accepted.is_empty(), "returned a transaction: {accepted:?}");
        for (name, result) in results {
            let msg = result.unwrap_err().msg;
            assert!(msg.contains("added no signature"), "{name}: {msg}");
        }
    }

    #[test]
    fn signing_a_pset_already_signed_by_the_same_key_fails() {
        let network = LiquidNetwork::Testnet;
        let descriptor =
            Descriptor::new_confidential(network, ABANDON_MNEMONIC.to_owned()).unwrap();
        let wallet = offline_wallet("sign-twice", descriptor);
        let mut signed =
            PartiallySignedTransaction::from_str(&pset_spending_first_address(&wallet)).unwrap();
        let added = SwSigner::new_with_network(ABANDON_MNEMONIC, LiquidNetwork::Testnet.into())
            .unwrap()
            .sign(&mut signed)
            .unwrap();
        assert_eq!(added, 1);
        let signed = signed.to_string();

        let results = [
            (
                "sign_tx",
                wallet.sign_tx(network, signed.clone(), ABANDON_MNEMONIC.to_owned()),
            ),
            (
                "signed_pset_with_extra_details",
                wallet.signed_pset_with_extra_details(
                    network,
                    signed.clone(),
                    ABANDON_MNEMONIC.to_owned(),
                ),
            ),
            (
                "sign_tx_with_seed",
                wallet.sign_tx_with_seed(network, signed.clone(), abandon_seed()),
            ),
            (
                "signed_pset_with_extra_details_with_seed",
                wallet.signed_pset_with_extra_details_with_seed(network, signed, abandon_seed()),
            ),
        ];
        for (name, result) in results {
            let msg = result.unwrap_err().msg;
            assert!(msg.contains("added no signature"), "{name}: {msg}");
        }
    }

    #[test]
    fn signing_rejects_a_seed_of_invalid_length() {
        let network = LiquidNetwork::Testnet;
        let descriptor =
            Descriptor::new_confidential(network, ABANDON_MNEMONIC.to_owned()).unwrap();
        let wallet = offline_wallet("sign-short-seed", descriptor);
        let pset = pset_spending_first_address(&wallet);

        // 16 and 32 bytes are BIP39 entropy lengths, the likeliest mistake for a seed.
        for len in [15, 16, 32, 63, 65] {
            let err = wallet
                .sign_tx_with_seed(network, pset.clone(), vec![0u8; len])
                .unwrap_err();
            assert!(err.msg.contains("a BIP39 seed is 64 bytes"), "{}", err.msg);
            let err = wallet
                .signed_pset_with_extra_details_with_seed(network, pset.clone(), vec![0u8; len])
                .unwrap_err();
            assert!(err.msg.contains("a BIP39 seed is 64 bytes"), "{}", err.msg);
        }
    }

    /// A regtest wallet built offline in its own temporary directory, removed afterwards.
    fn with_regtest_wallet(name: &str, policy_asset: Option<String>, test: impl FnOnce(&Wallet)) {
        let dbpath = std::env::temp_dir().join(format!("lwk-dart-{name}-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&dbpath);
        let descriptor =
            Descriptor::new_confidential_from_seed(LiquidNetwork::Regtest, abandon_seed()).unwrap();
        let wallet = Wallet::init(
            LiquidNetwork::Regtest,
            dbpath.display().to_string(),
            descriptor,
            policy_asset,
        )
        .unwrap();
        test(&wallet);
        drop(wallet);
        let _ = std::fs::remove_dir_all(&dbpath);
    }

    #[test]
    fn regtest_wallet_is_built_offline() {
        with_regtest_wallet("regtest-default", None, |wallet| {
            assert_eq!(
                wallet.policy_asset().unwrap(),
                super::super::types::L_REGTEST_ASSET_ID
            );
            let address = wallet.address(0).unwrap();
            assert!(
                address.confidential.starts_with("el1"),
                "{}",
                address.confidential
            );
            assert!(address.standard.starts_with("ert1"), "{}", address.standard);
            assert_eq!(
                Address::validate(address.confidential.clone()).unwrap(),
                LiquidNetwork::Regtest
            );
            // An unsynced wallet reports its policy asset, at zero.
            let balances = wallet.balances().unwrap();
            assert_eq!(balances.len(), 1);
            assert_eq!(
                balances[0].asset_id,
                super::super::types::L_REGTEST_ASSET_ID
            );
            assert_eq!(balances[0].value, 0);

            // A regtest wallet only pays regtest addresses.
            let testnet = "tlq1qq2xvpcvfup5j8zscjq05u2wxxjcyewk7979f3mmz5l7uw5pqmx6xf5xy50hsn6vhkm5euwt72x878eq6zxx2z58hd7zrsg9qn";
            let network = wallet.get_wallet().unwrap().network();
            assert!(validate_out_address(&address.confidential, network).is_ok());
            assert!(validate_out_address(testnet, network).is_err());
        });
    }

    #[test]
    fn regtest_wallet_takes_the_node_policy_asset() {
        let custom = "b2e15d0d7a0c94e4e2ce0fe6e8691b9e451377f6e46e8045a86f7c4b5d4f0f23";
        with_regtest_wallet("regtest-custom", Some(custom.to_string()), |wallet| {
            assert_eq!(wallet.policy_asset().unwrap(), custom);
        });
    }

    #[test]
    fn testnet_and_mainnet_wallets_reject_a_policy_asset() {
        let dbpath =
            std::env::temp_dir().join(format!("lwk-dart-fixed-asset-{}", std::process::id()));
        for network in [LiquidNetwork::Mainnet, LiquidNetwork::Testnet] {
            let descriptor =
                Descriptor::new_confidential(network, ABANDON_MNEMONIC.to_owned()).unwrap();
            let result = Wallet::init(
                network,
                dbpath.display().to_string(),
                descriptor,
                Some(super::super::types::L_REGTEST_ASSET_ID.to_string()),
            );
            assert!(result.is_err());
        }
        assert!(!dbpath.exists(), "rejected before touching the store");
    }

    /// POST `{"address": address, "amount": 1}` to a Nigiri-style faucet over plain HTTP.
    fn request_regtest_faucet(faucet_url: &str, address: &str) {
        use std::io::{Read, Write};
        let rest = faucet_url
            .strip_prefix("http://")
            .expect("LWK_REGTEST_FAUCET must be an http:// URL");
        let (host_port, path) = rest.split_at(rest.find('/').unwrap_or(rest.len()));
        let path = if path.is_empty() { "/" } else { path };
        let body = format!(r#"{{"address":"{address}","amount":1}}"#);
        let request = format!(
            "POST {path} HTTP/1.1\r\nHost: {host_port}\r\nContent-Type: application/json\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{body}",
            body.len()
        );
        let mut stream = std::net::TcpStream::connect(host_port).expect("faucet unreachable");
        stream
            .set_read_timeout(Some(std::time::Duration::from_secs(15)))
            .unwrap();
        stream
            .set_write_timeout(Some(std::time::Duration::from_secs(15)))
            .unwrap();
        stream.write_all(request.as_bytes()).unwrap();
        let mut response = String::new();
        stream.read_to_string(&mut response).unwrap();
        let status = response.lines().next().unwrap_or_default();
        assert!(status.contains(" 200 "), "faucet replied {response}");
    }

    /// The wallet's balance of its policy asset.
    fn policy_balance(wallet: &Wallet) -> u64 {
        let policy_asset = wallet.policy_asset().unwrap();
        wallet
            .balances()
            .unwrap()
            .into_iter()
            .find(|balance| balance.asset_id == policy_asset)
            .map_or(0, |balance| balance.value)
    }

    /// Sync until the policy balance exceeds `before`, for at most about 20 seconds.
    fn sync_until_funded(wallet: &Wallet, electrum_url: &str, before: u64) -> u64 {
        for _ in 0..20 {
            wallet
                .sync(electrum_url.to_owned(), false, None, None)
                .unwrap();
            let balance = policy_balance(wallet);
            if balance > before {
                return balance;
            }
            std::thread::sleep(std::time::Duration::from_secs(1));
        }
        panic!("the faucet payment never reached the wallet");
    }

    /// Fund, spend and broadcast on a local Elements regtest stack such as Nigiri:
    ///
    /// ```sh
    /// nigiri start --liquid
    /// LWK_REGTEST_ELECTRUM=tcp://127.0.0.1:50001 \
    /// LWK_REGTEST_FAUCET=http://127.0.0.1:3001/faucet \
    /// cargo test -- --ignored regtest_round_trip_over_plaintext_electrum
    /// ```
    #[test]
    #[ignore = "needs a local regtest stack; set LWK_REGTEST_ELECTRUM and LWK_REGTEST_FAUCET"]
    fn regtest_round_trip_over_plaintext_electrum() {
        let electrum_url =
            std::env::var("LWK_REGTEST_ELECTRUM").expect("LWK_REGTEST_ELECTRUM must be set");
        let faucet_url =
            std::env::var("LWK_REGTEST_FAUCET").expect("LWK_REGTEST_FAUCET must be set");
        let network = LiquidNetwork::Regtest;
        with_regtest_wallet("regtest-e2e", None, |wallet| {
            // The stack may have funded this mnemonic before: count only the new payment.
            wallet
                .sync(electrum_url.clone(), false, None, None)
                .unwrap();
            let before = policy_balance(wallet);
            let address = wallet.address_last_unused().unwrap().confidential;
            request_regtest_faucet(&faucet_url, &address);
            sync_until_funded(wallet, &electrum_url, before);

            let own_address = wallet.address_last_unused().unwrap().confidential;
            // 1 sat/vB: 0.1 sat/vB is below the regtest node's minimum relay fee.
            let pset = wallet
                .build_lbtc_tx(10_000, own_address, 1000.0, false)
                .unwrap();
            let signed = wallet
                .sign_tx_with_seed(network, pset, abandon_seed())
                .unwrap();
            let txid =
                Blockchain::broadcast_signed_pset(network, electrum_url.clone(), signed).unwrap();
            // Wait for the local stack to mine a block and for Electrum to index it.
            for _ in 0..30 {
                wallet
                    .sync(electrum_url.clone(), false, None, Some(5))
                    .unwrap();
                if wallet
                    .txs()
                    .unwrap()
                    .iter()
                    .any(|tx| tx.txid == txid && tx.height.is_some())
                {
                    return;
                }
                std::thread::sleep(std::time::Duration::from_secs(1));
            }
            panic!("the seed-signed transaction must be confirmed after broadcast");
        });
    }

    #[test]
    fn fee_rate_rejects_values_that_cannot_be_meant() {
        // lwk turns each of these into a silently wrong fee rather than an error.
        assert!(validate_fee_rate(f32::NAN).is_err(), "NaN yields a 0 sat fee");
        assert!(
            validate_fee_rate(f32::INFINITY).is_err(),
            "infinity yields a u64::MAX fee"
        );
        assert!(validate_fee_rate(-5.0).is_err(), "negative yields a 0 sat fee");
        assert!(validate_fee_rate(0.0).is_err());
        assert!(
            validate_fee_rate(1_000_000.0).is_err(),
            "1000 sat/vB is far past any plausible Liquid fee"
        );
    }

    #[test]
    fn fee_rate_accepts_the_usable_range() {
        assert!(validate_fee_rate(100.0).is_ok(), "0.1 sat/vB, typical for Liquid");
        assert!(validate_fee_rate(1000.0).is_ok(), "1 sat/vB");
        assert!(validate_fee_rate(MAX_FEE_RATE_SATS_PER_KVB).is_ok());
    }

    #[test]
    fn fee_rate_reaches_lwk_in_sats_per_kvb_unchanged() {
        for rate in [0.1, 100.0, 1000.0, MAX_FEE_RATE_SATS_PER_KVB] {
            assert_eq!(validate_fee_rate(rate).unwrap().to_sat_kvb(), rate);
        }
    }

    #[test]
    fn out_address_must_match_the_wallet_network() {
        // Liquid testnet confidential address, from lwk_wollet's own test.
        let testnet = "tlq1qq2xvpcvfup5j8zscjq05u2wxxjcyewk7979f3mmz5l7uw5pqmx6xf5xy50hsn6vhkm5euwt72x878eq6zxx2z58hd7zrsg9qn";

        assert!(validate_out_address(testnet, lwk_wollet::Network::TestnetLiquid).is_ok());
        assert!(
            validate_out_address(testnet, lwk_wollet::Network::Liquid).is_err(),
            "a testnet address must be refused on a mainnet wallet"
        );
    }

    #[test]
    fn out_address_must_be_confidential() {
        // Same key material as the address above, without the blinding key:
        // a valid testnet address that leaks amount and recipient.
        let confidential = "tlq1qq2xvpcvfup5j8zscjq05u2wxxjcyewk7979f3mmz5l7uw5pqmx6xf5xy50hsn6vhkm5euwt72x878eq6zxx2z58hd7zrsg9qn";
        let parsed = LwkAddress::parse_with_params(
            confidential,
            lwk_wollet::Network::TestnetLiquid.address_params(),
        )
        .unwrap();
        let explicit = parsed.to_unconfidential().to_string();

        assert!(
            validate_out_address(&explicit, lwk_wollet::Network::TestnetLiquid).is_err(),
            "an unblinded address must be refused"
        );
    }

    #[test]
    fn sync_accepts_an_electrum_url_with_or_without_a_scheme() {
        let mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about";
        let network = LiquidNetwork::Testnet;
        let desc = Descriptor::new_confidential(network, mnemonic.to_string()).unwrap();
        let dbpath = std::env::temp_dir().join(format!("lwk_sync_scheme_{}", std::process::id()));
        let wallet =
            Wallet::init(network, dbpath.to_string_lossy().into_owned(), desc, None).unwrap();

        // Nothing listens on port 1: each URL must get as far as connecting,
        // rather than failing to parse.
        for url in ["localhost:1", "ssl://localhost:1", "tcp://localhost:1"] {
            let err = wallet.sync(url.to_string(), true, None, Some(1)).unwrap_err();
            assert!(err.msg.contains("ConnectionRefused"), "{url}: {}", err.msg);
        }
        let _ = std::fs::remove_dir_all(dbpath);
    }

    #[test]
    #[ignore = "live mainnet integration test; set LWK_MAINNET_TEST_MNEMONIC"]
    fn testable_wallets() {
        let mnemonic = std::env::var("LWK_MAINNET_TEST_MNEMONIC")
            .expect("LWK_MAINNET_TEST_MNEMONIC must be set");
        let electrum_url = "les.bullbitcoin.com:995".to_string();
        let network = LiquidNetwork::Mainnet;
        let desc = Descriptor::new_confidential(network, mnemonic).unwrap();
        let wallet = Wallet::init(network, "/tmp/lwk".to_string(), desc, None).unwrap();
        let _ = wallet.sync(electrum_url.clone(), true, None, None);
        let _txs = wallet.txs();
        for tx in _txs.unwrap() {
            println!("{:?}\n{:?}\n{:?}", tx.balances, tx.timestamp, tx.height)
        }
        let balances = wallet.balances();
        // let _address = wallet.address_last_unused();
        // println!("{:#?}", address);
        println!("{:#?}", balances);
        // let out_address = "lq1qqdvmhsrn8fehfurv0yzgve2xfhrfxj9yax7t6wymzuvfj2w2y49v4jf3730067gp3xhkhw73083tvx3xryasvf32pe06sajwu".to_string();
        // let pset = wallet.build_lbtc_tx(0, out_address, 1000.0, true).unwrap();
        // let signed = wallet.sign_tx(network, pset, mnemonic.to_string()).unwrap();
        // let _ = Wallet::broadcast_tx(electrum_url.clone(), signed).unwrap();
        // let _ = wallet.sync(electrum_url.clone());
        // let _txs = wallet.txs();
        // for tx in _txs.unwrap(){
        //     println!("{:?}\n{:?}\n{:?}", tx.balances, tx.timestamp, tx.height)
        // }
        // thread::sleep(Duration::from_secs(60));
        // let _ = wallet.sync(electrum_url.clone());
        // let _txs = wallet.txs();
        // for tx in _txs.unwrap(){
        //     println!("{:?}\n{:?}\n{:?}", tx.balances, tx.timestamp, tx.height)
        // }
    }
    #[test]
    fn test_batch_sizes() {
        assert_eq!(batch_sizes(500, 250), (2, 250));
        assert_eq!(batch_sizes(501, 250), (3, 167));
        assert_eq!(batch_sizes(126, 250), (1, 126));
        assert_eq!(batch_sizes(251, 250), (2, 126));
    }

    #[ignore = "hits a live testnet electrum server"]
    #[test]
    fn test_consolidate() {
        // set your own funded testnet mnemonic here
        let mnemonic = "bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon";
        let electrum_url = "elements-testnet.blockstream.info:50002".to_string();
        let network = LiquidNetwork::Testnet;

        let desc = Descriptor::new_confidential(network, mnemonic.to_string()).unwrap();
        let wallet = Wallet::init(network, "/tmp/lwk_consolidate".to_string(), desc, None).unwrap();
        wallet.sync(electrum_url, true, None, None).unwrap();

        let count = wallet.utxos().unwrap().len();
        println!("total utxos: {count}");

        // threshold = 0 forces it to run even with few coins
        let psets = wallet.consolidate(0.1, Some(0), Some(250)).unwrap();
        // or, to use lwk's defaults (125 / 250):
        // let psets = wallet.consolidate(0.1, None, None).unwrap();
        println!("consolidate returned {} PSET(s)", psets.len());

        if let Some(first) = psets.first() {
            let decoded = wallet.decode_tx(first.clone()).unwrap();
            println!("first pset decoded: {decoded:?}");
        }
    }
    #[ignore = "hits a live testnet electrum server"]
    #[test]
    fn test_build_custom_tx() {
        // set your own funded testnet mnemonic here
        let mnemonic = "bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon";
        let electrum_url = "elements-testnet.blockstream.info:50002".to_string();
        let network = LiquidNetwork::Testnet;

        let desc = Descriptor::new_confidential(network, mnemonic.to_string()).unwrap();
        let wallet =
            Wallet::init(network, "/tmp/lwk_build_custom_tx".to_string(), desc, None).unwrap();
        wallet.sync(electrum_url, true, None, None).unwrap();

        let utxos = wallet.utxos().unwrap();
        assert!(!utxos.is_empty(), "wallet needs at least one confirmed UTXO");
        let outpoint = utxos[0].outpoint.clone();

        let decoy_address = wallet.address(1).unwrap().confidential;
        let drain_address = wallet.address(2).unwrap().confidential;

        // One explicit 1-sat decoy output plus the drained remainder — should
        // produce a PSET with exactly 2 outputs (excluding the fee output).
        let pset = wallet
            .build_custom_tx(
                vec![outpoint],
                vec![TxOutputSpec {
                    address: decoy_address,
                    satoshi: 1,
                    asset_id: None,
                }],
                Some(drain_address),
                0.1,
            )
            .unwrap();

        let decoded = wallet.decode_tx(pset).unwrap();
        println!("build_custom_tx decoded: {decoded:?}");
    }

    #[ignore = "disabled because it broadcasts a pre-signed tx against a live server (inputs long spent)"]
    #[test]
    fn test_broadcast() {
        let signed = "020000000101922c31e356f4c7c9c34a67b99fe8b691c9a892cf8d2bd43024c3bdb92b747ec60100000000ffffffff020b79265edeec56f0f7cab1a5183277131c95c82d619728e407595da2dedf119f9b087fb337572d8d639bfd24f2e6dc54f590cddd9869da94b32ddb887fcb324eef9602f12307ef4bbda2ee871867017a325ade116698f28e79d564e3be6ec2e9ef0c42160014b4620e4b3d559352bdf1f313898fd040c2851850016d521c38ec1ea15734ae22b7c46064412829c0d0579f0a713d1c04ede979026f01000000000000000e00000000000000000140e057d54dc4fe0e02a99e09cc071cfb8869e53541f84255ab519964aae882218d194e23b13a1859a203e904955771034097dcf015514c0bbb0f7a66a2585355500043010001e77791d70a6ce5f1b3339a67a1ad46d528f1ed5417148dbdd629d89a3f2753b32a5933b498177a6f0df2c6f0cdc41912afe5d90abb7acb65a68b76e8f625f5fffd4e1060330000000000000001c53add01928582113dd9853d2f66797f032daef0d09e4b6c1b7269803488e0454dd1ab021e027760d1c92e88a394c2fdab2afd8ae1d4f65d213a4e15aea273547d02039685b2dd47df0d158eed2210794e8f07a5d0b66c3d7177316381b192236075dd82cdb57d7d09225e60fa8bba304f79fc11958dc861383c05375e3a703f5f2a4d4c26df108be4c2d678455ba411b9d2da474e48990612ad2041390be2b9d835e4998e99f3116934d15014880265136cd81a61f05fc421e03f967cfeb51b0d696cbc8ef8a4cd90a062a93ab0fa3d5fe2083f55bbae1734e9fd4e5dbaec929105458a984e41f55804188e7e8021cebac720f7c6c0f2c15f33078429a9bc14977a47cef156304f84ee053682df465ea0751bf55ac6471b6c27c9de705c7dc7172c95c379b659ee7bae4707c2a536648ac665d363a0fef910fe94345f8c9ad209a57705faff6a508759f9dcc9e790ef354091c7d5c96ac5d6311b9673e63b94db15b082ac5e4949ab99907ade64d074504007d4b4c1965fe41cb5a0ce8612318f1269d8f213d8494f5dabb2a57bd7e6008a53b3ad57650667d585be1ab7a5b2bf61aae507e4535612008950dfcfc1563c59597c790d9ce62abafde1e473434e4e6ba59bc875cd308220ad2dd69784b5cf24ee3a2945f5e6aacd4cc573730464407818adc532e83f4022b30caccf26d3b778400fc6a0e2a95e648552b976385b6739e22cf07db6e6c7cef6cad9108d235c128af1dd2ce8a04a024fab8140037bf21592653b7f74cb06528b44e1631549da0b407075df3acd552463ed389057a529e5f8d475031ffadfb7af918242a2d9d179f9336041845e1a06b7c1a25b9869ad4a48d8f6967a5985d65d56fa258e2f81f1e983c092daf80f3448b2663d247281e8ccda57d5f78c813ee7c30199956acbce71acbb9e88b101f0c99c9dd30cb916ce5fa9b7bdd6dd473a1306c04dde44a70f1261932acb51bdf021327acf6d60108a1f53ff5fd871cb158de1007d079f040ef9ea426186e21590c964ad88fb8c9fb6fb57e5e6db5c7b4dad8b283821538ab243f1344997e788bff13858508800f31722f21b1d07f37c6c389f861bf847dd19a372868e48fe40a8a7086b116d758e40425ce52f83ec1b7c1599de675804b9561bc09a6d2381c848097add051a63141e01d4847f286ae10acbeb06ca615d04ea6b0d265c04986c4641ffff8a1cc412e2a0fd9f5fe42da282003306fc57a31d70115559d2012e9b52f08293e6925bc496b1659c6a870ae4871f7fbf5c4ea0c02810b7c9a8bbff835fd43fac1cb13f44e3228dca4d4252c381da7e359259fa6ee4cba9e78bcf31db837c35dcdf40d5fc7bf40380d8602b51175ec37fb1f35fcfa7fbf0601de8bac23ff47d74e07f4748bac55162d1dc7b24510efa173c4a9029066a7ea8d4e887fbbb7691922920b635129ef1b040c67631d94ac449fe359732dc28c0dd6ab99a3dfbb0c5da9706b559b42d1d850bf24455a43355f75dbe1047b111992881077c79183362c593f5e4469783050a4272eef71b0162268ed4d10163de154a7dc794aff17d95b0427c89bb1539876b4c98889b26173e5e1f9efd2e6069ca1d531f2d9c26c838f3d3bf4bf1b2b212e4cd3ffdacd289016d68095bf5e16eaad841b91378eab041436b62b61ffca0af804ab804e25577e5093a454f92e28ed9954767bc8dfb0aa7aab801ba6471e9f56508e37980661bb8bba7bd6c591fd1ce5ef8f8e8d8cff1d95f64c7d635b6fbc28723cd761297cb931796abe512989ec7b465d3be0544afcf896bc05b2cb4e82beab2aa9a7d4a539ccd31f3d2ce2070616039e4e38ce56518c6a617cc5574549f9bb41500371f5c5e2d65bc1af7304391bf5a8b34fea16eb6f4a5aeeb3c19be4f0b271326a45a85fb2eafef79c0b058553d4789fbcb2589c524e455e40a036becf64f883107918d56ba8888e70cfcce6bc8222b59c544d2cc9308979bec80de20d6ac25fe1af7f9851a84a76b175a084d690b6fb41db805d35faf58409a5c4de2bf08d4088cf436eb4172bda6a643c5cb14163f2fa34396422f006b1525e24fc9efa7c810dac298426c92575d9caf7918b683fc8e2a431627d5cc60d5058130e009e6976578388743c4d4e8bd9c46d7c4c8e374a7654541cd08ed9b013168f9f519dc72df29189d5f3f5ef0d14dde526a1c3f6907f49361f04b4f80b8f14188134788d7bedd81b912dd0a166e9d1b1c6c2ae9eea5e7fe15b773fd9d054fe8aea5ce4f40a0d8bf0eb1a617fc29d0fbb08a30b6c2fd2cdc9eff0b6d826c4b8256a557145c5bc7b4ba10faf4fdfffd3ae7e17d5b412de9fc1db9d069e857d91b3131bcebcffd43d2a5d47888c7e40dcabd9baba36fcdb4ca846f07f80bce3c668e0bf9b065ee74637963a240f1110d37c5893e8b5cc181742fe6616abc149e27d4568fe2c61a068bc1143247a294986ecaf7e867840d36a2db8851d80089f52282f317be3041993f09752e2d9fdfe450722c45666ab9749134f64b2621d11ba3d602bad5ad17ede55a32acc7a679095668001d63f68df95888c7d2ac0c456d26b31bb9a37b6f8af1663ec6677299160a6e214dc20e0893e656aa742e99fd450a70d958fd07408dc3ff81426c56c89590f65be64e524f54b5624a349d53bc7183044504f577a5168f1027aa1f6fb3dc81ae3d310be3d0c686df49c9c22a30c4902b716436bbb205e57109218f11016bc1dc0e3eeffda77b7e59494395d46f00c5e708e45b56f3be295c304a1aebe7d97fc8a04b2d7f6468861f4157d18a34b8ea0d69862c5d371b5419abbcefb4c72dbad13ed003eac0adc13465ab9513f20d21bfbb9d0b8a72115fa7754726f8e4b87bd9023be5201f9b9c628474f5f4e969d08edc5d328ef69cfe9f25fb703fc2c6f71a777942eca810335299832ee02c5c64ef3e9123df8ad99b7a0ac3f8f1f682598b441237e4f46fb8443a9e6a9693bd03357b6bd31a5940815b2572f2919d21b4a0f036c3a4d47ba96aca930f6303a2677936a9b581de54debb4a0e9a36408647b6539da8de645b1b206fd99fb45c7f4fa45b56fac448ed79d7f227874a9b99b1dbce4008d14938a9b948c41e5f8d2a6dab6615b6b3188dc64b9df4a12152de7c34c17da0995aea1c4686ce69faf759051bfea40054f9784f1239ad375ee7615d8cdbabfb7ecbb3efc768d213cfab3b590d2e669d400ff6e14423934066ae1d52661f9848281e100ecc07175774881cab08480abb7d4b045d6a6c6f11ed6384c5fd87364d589cacb0b1ee64416122d2cc1aae1127645094387195cac1be0482053ea88cb48e789cb53420b5b96014bcfedc8923af90b3eb5ff8cf0e25c689ce2b9b85077c4328b6be60751784f878dab69f66e9ed5af76ba74c0cb9eb9749926dd5fd0cf4666a0cb10e94271bc877564b0430c93032584a4e9a71276ddeaf4bc5ed07920e73f1fe7d570e08ddfd9ae4a3ecd263925fda377431dad4c3616383f45cf0ca006919993803c54970b5c207867143b95335ffa9b2ec58922afec07c0675cd9476c8e23838ec56346f29d736a3501b5e199dd9c82ac97e63cc46654a243be9319434fa47bee193e02a7c5f29e2acbd0c830f68b601e6b9dd3b4501a3da2d9b9dfc5c3ad8511077a3e88789ccd1faa286d02566d31d8bad81b59ea8896acc5aee677b4ead947c29d8cf8ad1c60d08a2ac5deda1442d12ce5ab8f192d6fed89e81ffab6b6763261c1515e4147434b65af2dfabebaa46e74e4ac720e124abf23e3145a8e526bca9053ab36fb0617458121212874bb307329bc09a8e6008f2d84fa305141cfb4bd20d75a02aa8e3c84077918236e4acf5a8962885faeb3a00459d62383e710ece8e49bfc7eb683820c740f0eadae59d5e70d8a3069ff795a63915af5de8f0a31bae0b48720f54d70e6cba848861769bf48625a1933d0dd6740b18328091cd6e052c53f278ddb9bedb26ba88f901324be4187fd63e1f47a325d5d958e1ccacf289ac24cf716b25f8c371c1f2fbbc4c7ffd0e4adc9aaba872ca4396ddf3291e7ef4b2bdd5e648a824778728915e64cb20e809ba6da6f5f7bbfd6b95e0ca435beeca8e9ce72c8d78010d80c5387acb3b728c213bfb4a3811699a660f2a0f057e580605c07248f2b0b0ef8168fa2c860d3ac4e2e718d0dafdf1587e80c7ec8b12b5808fcc185ec3c4efba71bc51a97758675314355cf97a90302befa70ecbe39d1c90f59091aa75811aa836c27da61e069facba2b7b6bf1c0f92a975502a6c09e0d87ce24f9825ba86ce2a12d4a36765f02c3ae9625d9735fa2f62115086f52294ed222f49c9a0bf641585102f095ec4af2310171ccefdf205227558ab202dfaf8095cb1acc0b2bc7efc327d7b7bcf89f5279a2a4dcd08f6660fd03b6726095b687fb69f428b8fce0a4f45fe0bd79e47b21dc432beec2f434de5e0cfc9f7b582bb6b5e9ac66ab2cdacb7bcdab72a3459678bc60ce5ebd6edefe216ec9f43263afc147417a658651efb34c848acaadd9433cd2a7594c8b9fb6af64f23cd6bda4c1d88983ae4e1b4375c508020d9f45e66a92173ec5eaf166f86f3e1680e3f0bbf2bfbe180f5eb7f7e50e61eb74183b70b78ce66f36d06a3a54dcd94f7debde7617b8e5136be327e7dacb5464c68bf3c0c859e402bd97479ab2d5ab6d6b4166929c673594285743961df427e41b024051a0f590ea697c08df7c19011db1d008cdb5b956a35574ec067b49eba9ac25c5ba4fe095a654cd435ec01a51557c10fea2191212df4804cab8f7977e1c21b8d61f45f6627b74cfaf67bedfea611015058828a47089fee74dc594f1b6d29786d7cf6681b700939c6f2b78520ec82cc5a206e2e5d973fc6eac04a023b82fe308917d4a94d03107dbc77aae755c46053118c778687760cfcf5382edfe19f1ad23b050f674ee0dba4f146bba9c532abef8d0abb4e83b428345baaa1c4e4f9d8a443e9dd8788c3fcf4aa4f6b7a789b1173d968ee750e7f9af775ed94782b70797793e047691478d66e798bcbe026b818d97e6c8cb98f110c47ba095e3da0f0512e9f507c2000590d2045466fed48fe85901bc35a2c8a770d78f5d9e0c793e50be3be14752ce073df375f9ba1f5eee8271beee439422f77549eda11908e93a0a246f38e23d88c7b231cf089859e37ec668302cbeaf066c0152a15914762f17d1451fb628343c650e9ef1ed47d98ddcd455126521802b2df879b921cb9866ebaffc2746f98f4f419fd6d8eb3d0c6c7f436b1e12d0ad97f02b004b3ee85b1a58a700171baa25ab8a0429d4b6c71cfa4068a0b661f8521e17d6e1cbe317bef788e4bb638bf6c169622eb9b6a91c3a8f386534b53d17cdcd2837188121d48ade9f5a8f5814ce251006c25f9ddfff547dab63be13509d317538119637bd59aae246800ed4c1aaf10694286f4956b25644647bd5683b89a612f0db4a62d23eb7fe750ee7a442f627bc154aea8ef4eb83b33d0ee07d41b4dcab82dda1c185a931b7fcf190baf68bda903ad0b3916a2601c0ebc7cfaf8e588948adc5cc8f1ad66360da273d7897cf03642d7eaa58273ba4e171b75525feee84d33a94d0d74d2628a4bd3cb8b12337d65c716829ea58990e21b24e818fb93e869423f11aba67aefaebb05a201bf8e4aa07cb27003c4faded8c22aac4ae69088542ddc4de3c0b8ac261e21d4e24e10702af2e60072db1608b84bbb234e5a60e5a99b0e735cde9bd172285c91c477a7d9896942668ecfa089f2a596d7dcfaeae135cb15c8ccaf4a46469ef27b4164c948c9f3314a993c36320ad9cb3654b59a8f35d6371992e1f00f24ef7ac8493611f6b7dfe72c84447675b94999c17cdce9371095633c0579a03615e944b280000";
        let electrum_url = "les.bullbitcoin.com:995".to_string();
        let tx_bytes = hex::decode(signed).unwrap();
        let txid =
            Blockchain::broadcast_tx_bytes(LiquidNetwork::Mainnet, electrum_url, tx_bytes).unwrap();
        println!("TXID: {}", txid);
    }

    // #[test]
    // fn test_external_utxo() {
    //     // Send tx with external utxos
    //     let server = setup(false);
    //     let signer1 = generate_signer();
    //     let view_key1 = generate_view_key();
    //     let desc1 = format!("ct({},elwpkh({}/*))", view_key1, signer1.xpub());
    //     let mut w1 = TestWollet::new(&server.electrs.electrum_url, &desc1);

    //     let signer2 = generate_signer();
    //     let view_key2 = generate_view_key();
    //     let desc2 = format!("ct({},elwpkh({}/*))", view_key2, signer2.xpub());
    //     let mut w2 = TestWollet::new(&server.electrs.electrum_url, &desc2);

    //     let policy_asset = w1.policy_asset();

    //     let address = w1.address();
    //     w1.fund(&server, 100_000, Some(address), None);

    //     let address = w2.address();
    //     w2.fund(&server, 100_000, Some(address), None);

    //     let utxo = &w2.wollet.utxos().unwrap()[0];
    //     let external_utxo = w2.make_external(utxo);

    //     let node_address = server.node_getnewaddress();
    //     let mut pset = w1
    //         .tx_builder()
    //         .add_lbtc_recipient(&node_address, 110_000)
    //         .unwrap()
    //         .add_external_utxos(vec![external_utxo])
    //         .unwrap()
    //         .finish()
    //         .unwrap();

    //     // Add the details for the extenal wallet to sign
    //     w2.wollet.add_details(&mut pset).unwrap();
    //     let details = w1.wollet.get_details(&pset).unwrap();
    //     assert_eq!(details.sig_details.len(), 2);
    //     assert_eq!(details.sig_details[0].missing_signature.len(), 1);
    //     assert_eq!(details.sig_details[1].missing_signature.len(), 1);

    //     let signers = [&AnySigner::Software(signer1), &AnySigner::Software(signer2)];
    //     for signer in signers {
    //         w1.sign(signer, &mut pset);
    //     }

    //     let details = w1.wollet.get_details(&pset).unwrap();
    //     let fee = details.balance.fee;

    //     w1.send(&mut pset);

    //     let balance = w1.balance(&policy_asset);
    //     // utxo w1, utxo w2, sent to node, fee
    //     assert_eq!(balance, 100_000 + 100_000 - 110_000 - fee);

    //     // External UTXO cannot be asset UTXOs
    //     w2.sync();
    //     w2.fund_asset(&server);
    //     let utxo = &w2.wollet.utxos().unwrap()[0];
    //     let external_utxo = w2.make_external(utxo);

    //     let err = w1
    //         .tx_builder()
    //         .add_external_utxos(vec![external_utxo])
    //         .unwrap_err();
    //     assert_eq!(err.to_string(), "External utxos must be L-BTC");
    // }

    // #[test]
    // fn test_unblinded_utxo() {
    //     // Receive unblinded utxo and spend it
    //     let server = setup(false);

    //     let signer = generate_signer();
    //     let view_key = generate_view_key();
    //     let desc = format!("ct({},elwpkh({}/*))", view_key, signer.xpub());
    //     let mut w = TestWollet::new(&server.electrs.electrum_url, &desc);
    //     let signers = [&AnySigner::Software(signer)];

    //     let policy_asset = w.policy_asset();

    //     // Fund the wallet with an unblinded UTXO
    //     let address = w.address().to_unconfidential();
    //     let satoshi = 100_000;
    //     let txid = server.node_sendtoaddress(&address, satoshi, None);
    //     // Wait for the transaction
    //     let mut found = false;
    //     let mut electrum_client: ElectrumClient = ElectrumClient::new(&w.electrum_url).unwrap();
    //     for _ in 0..120 {
    //         full_scan_with_electrum_client(&mut w.wollet, &mut electrum_client).unwrap();
    //         if w.wollet.transaction(&txid).unwrap().is_some() {
    //             found = true;
    //             break;
    //         }
    //         std::thread::sleep(std::time::Duration::from_millis(500));
    //     }
    //     assert!(found, "Wallet have not received {}", txid);

    //     assert_eq!(w.balance(&policy_asset), 0);

    //     // TODO: expose a better way to fetch these utxos
    //     let tx = w.wollet.transaction(&txid).unwrap().unwrap();
    //     let vout = tx
    //         .tx
    //         .output
    //         .iter()
    //         .position(|o| o.script_pubkey == address.script_pubkey())
    //         .unwrap();
    //     let txout = tx.tx.output[vout].clone();
    //     let outpoint = elements::OutPoint::new(tx.txid, vout as u32);
    //     let unblinded = elements::TxOutSecrets::new(
    //         policy_asset,
    //         elements::confidential::AssetBlindingFactor::zero(),
    //         satoshi,
    //         elements::confidential::ValueBlindingFactor::zero(),
    //     );
    //     let external_utxo = lwk_wollet::ExternalUtxo {
    //         outpoint,
    //         txout,
    //         unblinded,
    //         max_weight_to_satisfy: 200, // TODO
    //     };

    //     // FIXME: this should be failing, transaction cannot be blinded
    //     /*
    //     let err = w
    //         .tx_builder()
    //         .add_external_utxos(vec![external_utxo.clone()])
    //         .unwrap()
    //         .drain_lbtc_wallet()
    //         .finish()
    //         .unwrap_err();
    //     assert_eq!(err.to_string(), "FIXME");
    //      * */
    //     // Create tx sending the unblinded utxo
    //     let node_address = server.node_getnewaddress();

    //     let mut pset = w
    //         .tx_builder()
    //         .add_lbtc_recipient(&node_address, 10_000)
    //         .unwrap()
    //         .add_external_utxos(vec![external_utxo])
    //         .unwrap()
    //         .finish()
    //         .unwrap();

    //     for signer in signers {
    //         w.sign(signer, &mut pset);
    //     }

    //     // Cannot get details
    //     let err = w.wollet.get_details(&pset).unwrap_err();
    //     assert_eq!(err.to_string(), "Input #0 is not blinded");

    //     w.send(&mut pset);

    //     // Received the change output
    //     assert!(w.balance(&policy_asset) > 0);

    //     // TODO: more cases
    // }
}
