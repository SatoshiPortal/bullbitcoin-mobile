use crate::wallet_policy::{ParsedWalletPolicy, PreparedWalletPolicy};
use crate::wallet_policy_psbt::{filter_psbt_for_device_keys, validate_supported_sighashes};
use anyhow::{anyhow, bail, Result};
use bitbox_api::{NoiseConfigNoCache, PairedBitBox, PairingBitBox};
use bitcoin::bip32::{DerivationPath, Fingerprint, Xpub};
use bitcoin::NetworkKind;
use flutter_rust_bridge::frb;
use lazy_static::lazy_static;
use std::collections::HashMap;
use std::str::FromStr;
use std::sync::Arc;
use tokio::sync::Mutex;

pub use crate::usb_bridge::{get_usb_write_data, set_usb_read_data, PlatformUsbBridge};

#[frb(sync)]
pub fn get_usb_write_data_wrapper(serial_number: String) -> Option<Vec<u8>> {
    crate::usb_bridge::get_usb_write_data(serial_number)
}

#[frb(sync)]
pub fn set_usb_read_data_wrapper(serial_number: String, data: Vec<u8>) -> Result<()> {
    crate::usb_bridge::set_usb_read_data(serial_number, data)
}


const FIRMWARE_CMD: u8 = 0x80 + 0x40 + 0x01;

#[derive(Debug, Clone)]
pub struct DeviceInfo {
    pub name: String,
    pub version: String,
    pub initialized: bool,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum BitBoxKeychain {
    Receive,
    Change,
}

lazy_static! {
    static ref BITBOX_DEVICES: Arc<Mutex<HashMap<String, PairedBitBox<bitbox_api::runtime::TokioRuntime>>>> = 
        Arc::new(Mutex::new(HashMap::new()));
    static ref BITBOX_PAIRING_DEVICES: Arc<Mutex<HashMap<String, PairingBitBox<bitbox_api::runtime::TokioRuntime>>>> =
        Arc::new(Mutex::new(HashMap::new()));
}

#[frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
}

#[frb]
pub async fn get_root_fingerprint(serial_number: String) -> Result<String> {
    let devices = BITBOX_DEVICES.lock().await;
    let bitbox = devices
        .get(&serial_number)
        .ok_or_else(|| anyhow!("Device not connected. Please perform handshake first."))?;
    
    let fingerprint = bitbox.root_fingerprint().await
        .map_err(|e| anyhow!("Failed to get root fingerprint: {:?}", e))?;
    
    Ok(fingerprint)
}

#[frb]
pub async fn get_device_info(serial_number: String) -> Result<DeviceInfo> {
    let devices = BITBOX_DEVICES.lock().await;
    let bitbox = devices
        .get(&serial_number)
        .ok_or_else(|| anyhow!("Device not connected"))?;
    
    let info = bitbox.device_info().await
        .map_err(|e| anyhow!("Failed to get device info: {:?}", e))?;
    
    Ok(DeviceInfo {
        name: info.name,
        version: bitbox.version().to_string(),
        initialized: info.initialized,
    })
}

#[frb]
pub async fn close_device(serial_number: String) -> Result<()> {
    let mut devices = BITBOX_DEVICES.lock().await;
    devices.remove(&serial_number);
    
    Ok(())
}

pub async fn close_usb_channel(serial_number: String) -> Result<()> {
    crate::usb_bridge::close_device(&serial_number).await;
    Ok(())
}

#[frb]
pub async fn start_pairing(serial_number: String) -> Result<Option<String>> {
    let usb_bridge = PlatformUsbBridge::new(serial_number.clone());
    let noise_config = NoiseConfigNoCache;

    let comm = Box::new(bitbox_api::communication::U2fHidCommunication::from(
        Box::new(usb_bridge),
        FIRMWARE_CMD,
    ));

    let bitbox = match bitbox_api::BitBox::<bitbox_api::runtime::TokioRuntime>::from(
        comm,
        Box::new(noise_config),
    ).await {
        Ok(bb) => bb,
        Err(_) => return Ok(None),
    };

    let pairing_bitbox = match bitbox.unlock_and_pair().await {
        Ok(pb) => pb,
        Err(_) => return Ok(None),
    };

    let pairing_code = pairing_bitbox.get_pairing_code();

    BITBOX_PAIRING_DEVICES.lock().await.insert(serial_number, pairing_bitbox);

    Ok(pairing_code)
}

#[frb]
pub async fn confirm_pairing(serial_number: String) -> Result<bool> {
    let mut pairing_map = BITBOX_PAIRING_DEVICES.lock().await;
    let pairing_bitbox = pairing_map.remove(&serial_number)
        .ok_or_else(|| anyhow!("No pending pairing for device"))?;

    let paired = pairing_bitbox.wait_confirm().await
        .map_err(|e| anyhow!("wait_confirm failed: {:?}", e))?;

    BITBOX_DEVICES.lock().await.insert(serial_number, paired);
    Ok(true)
}

#[frb]
pub async fn get_btc_xpub(serial_number: String, keypath: String, xpub_type: String) -> Result<String> {
    let devices = BITBOX_DEVICES.lock().await;
    let bitbox = devices.get(&serial_number)
        .ok_or_else(|| anyhow!("Device not paired"))?;

    let kp = bitbox_api::Keypath::try_from(keypath.as_str())
        .map_err(|e| anyhow!("Invalid keypath: {:?}", e))?;

    let xpub_ty = match xpub_type.to_lowercase().as_str() {
        "tpub" => bitbox_api::pb::btc_pub_request::XPubType::Tpub,
        "xpub" => bitbox_api::pb::btc_pub_request::XPubType::Xpub,
        _ => bitbox_api::pb::btc_pub_request::XPubType::Xpub,
    };

    let coin = match xpub_ty {
        bitbox_api::pb::btc_pub_request::XPubType::Tpub => bitbox_api::pb::BtcCoin::Tbtc,
        _ => bitbox_api::pb::BtcCoin::Btc,
    };

    let xpub = bitbox.btc_xpub(coin, &kp, xpub_ty, false).await
        .map_err(|e| anyhow!("Failed to get xpub: {:?}", e))?;

    Ok(xpub)
}

#[frb]
pub async fn verify_address(serial_number: String, keypath: String, testnet: bool, script_type: Option<String>) -> Result<String> {
    let devices = BITBOX_DEVICES.lock().await;
    let bitbox = devices.get(&serial_number)
        .ok_or_else(|| anyhow!("Device not paired"))?;

    let coin = if testnet { bitbox_api::pb::BtcCoin::Tbtc } else { bitbox_api::pb::BtcCoin::Btc };

    let simple_type = match script_type.as_deref().unwrap_or("p2wpkh").to_lowercase().as_str() {
        "p2wpkhp2sh" => bitbox_api::pb::btc_script_config::SimpleType::P2wpkhP2sh as i32,
        "p2wpkh" => bitbox_api::pb::btc_script_config::SimpleType::P2wpkh as i32,
        "p2tr" => bitbox_api::pb::btc_script_config::SimpleType::P2tr as i32,
        _ => bitbox_api::pb::btc_script_config::SimpleType::P2wpkh as i32,
    };
    let script_cfg = bitbox_api::pb::BtcScriptConfig {
        config: Some(bitbox_api::pb::btc_script_config::Config::SimpleType(simple_type)),
    };

    let kp = bitbox_api::Keypath::try_from(keypath.as_str())
        .map_err(|e| anyhow!("Invalid keypath: {:?}", e))?;
    let address = bitbox.btc_address(coin, &kp, &script_cfg, true).await
        .map_err(|e| anyhow!("Failed to display/verify address: {:?}", e))?;

    Ok(address)
}

#[frb]
pub async fn sign_psbt(serial_number: String, psbt_str: String, testnet: bool) -> Result<String> {
    let devices = BITBOX_DEVICES.lock().await;
    let bitbox = devices.get(&serial_number)
        .ok_or_else(|| anyhow!("Device not paired"))?;

    let coin = if testnet { bitbox_api::pb::BtcCoin::Tbtc } else { bitbox_api::pb::BtcCoin::Btc };

    let mut psbt = bitcoin::psbt::Psbt::from_str(psbt_str.trim())
        .map_err(|e| anyhow!("Invalid PSBT: {:?}", e))?;

    bitbox.btc_sign_psbt(coin, &mut psbt, None, bitbox_api::pb::btc_sign_init_request::FormatUnit::Default)
        .await
        .map_err(|e| anyhow!("Signing failed: {:?}", e))?;

    let out = psbt.to_string();
    Ok(out)
}

#[frb]
pub async fn is_wallet_policy_registered(
    serial_number: String,
    descriptor: String,
    testnet: bool,
) -> Result<bool> {
    let devices = BITBOX_DEVICES.lock().await;
    let bitbox = devices
        .get(&serial_number)
        .ok_or_else(|| anyhow!("Device not paired"))?;
    let policy = prepare_wallet_policy(bitbox, &descriptor, testnet).await?;
    let registration_keypath = policy
        .registration_keypath
        .as_ref()
        .map(bitbox_api::Keypath::from);

    bitbox
        .btc_is_script_config_registered(
            coin(testnet),
            &policy.script_config,
            registration_keypath.as_ref(),
        )
        .await
        .map_err(|error| anyhow!("Failed to check wallet registration: {error:?}"))
}

#[frb]
pub async fn register_wallet_policy(
    serial_number: String,
    descriptor: String,
    testnet: bool,
    name: Option<String>,
) -> Result<()> {
    let devices = BITBOX_DEVICES.lock().await;
    let bitbox = devices
        .get(&serial_number)
        .ok_or_else(|| anyhow!("Device not paired"))?;
    let policy = prepare_wallet_policy(bitbox, &descriptor, testnet).await?;
    let registration_keypath = policy
        .registration_keypath
        .as_ref()
        .map(bitbox_api::Keypath::from);

    bitbox
        .btc_register_script_config(
            coin(testnet),
            &policy.script_config,
            registration_keypath.as_ref(),
            bitbox_api::pb::btc_register_script_config_request::XPubType::AutoXpubTpub,
            name.as_deref(),
        )
        .await
        .map_err(|error| anyhow!("Failed to register wallet: {error:?}"))
}

#[frb]
pub async fn verify_wallet_address(
    serial_number: String,
    descriptor: String,
    testnet: bool,
    keychain: BitBoxKeychain,
    index: i64,
) -> Result<String> {
    let index = address_index(index)?;

    let devices = BITBOX_DEVICES.lock().await;
    let bitbox = devices
        .get(&serial_number)
        .ok_or_else(|| anyhow!("Device not paired"))?;
    let policy = prepare_wallet_policy(bitbox, &descriptor, testnet).await?;
    let keypath =
        policy.address_keypath(matches!(keychain, BitBoxKeychain::Change), index);

    bitbox
        .btc_address(
            coin(testnet),
            &bitbox_api::Keypath::from(&keypath),
            &policy.script_config,
            true,
        )
        .await
        .map_err(|error| anyhow!("Failed to verify wallet address: {error:?}"))
}

#[frb]
pub async fn sign_wallet_psbt(
    serial_number: String,
    descriptor: String,
    psbt_str: String,
    testnet: bool,
) -> Result<String> {
    let devices = BITBOX_DEVICES.lock().await;
    let bitbox = devices
        .get(&serial_number)
        .ok_or_else(|| anyhow!("Device not paired"))?;
    let policy = prepare_wallet_policy(bitbox, &descriptor, testnet).await?;
    let mut psbt = bitcoin::psbt::Psbt::from_str(psbt_str.trim())
        .map_err(|error| anyhow!("Invalid PSBT: {error:?}"))?;
    validate_supported_sighashes(&psbt)?;

    let mut signed = false;
    while let Some((mut signing_psbt, device_key)) =
        filter_psbt_for_device_keys(&psbt, policy.device_keys())?
    {
        bitbox
            .btc_sign_psbt(
                coin(testnet),
                &mut signing_psbt,
                Some(policy.script_config_with_keypath(device_key)),
                bitbox_api::pb::btc_sign_init_request::FormatUnit::Default,
            )
            .await
            .map_err(|error| anyhow!("Signing failed: {error:?}"))?;
        crate::wallet_policy_psbt::restore_existing_signatures(&mut signing_psbt, &psbt);
        if !crate::wallet_policy_psbt::merge_signatures(&mut psbt, signing_psbt)? {
            bail!("BitBox did not add a signature");
        }
        signed = true;
    }
    if !signed {
        bail!("PSBT does not contain an unsigned key controlled by the connected BitBox");
    }

    Ok(psbt.to_string())
}

async fn prepare_wallet_policy(
    bitbox: &PairedBitBox<bitbox_api::runtime::TokioRuntime>,
    descriptor: &str,
    testnet: bool,
) -> Result<PreparedWalletPolicy> {
    let expected_network = if testnet {
        NetworkKind::Test
    } else {
        NetworkKind::Main
    };
    let parsed = ParsedWalletPolicy::parse(descriptor, expected_network)?;
    let fingerprint = bitbox
        .root_fingerprint()
        .await
        .map_err(|error| anyhow!("Failed to get root fingerprint: {error:?}"))?
        .parse::<Fingerprint>()
        .map_err(|error| anyhow!("BitBox returned an invalid root fingerprint: {error}"))?;
    let mut device_xpubs = HashMap::<DerivationPath, Xpub>::new();

    for keypath in parsed.device_candidate_keypaths(fingerprint) {
        if device_xpubs.contains_key(&keypath) {
            continue;
        }
        let xpub = bitbox
            .btc_xpub(
                coin(testnet),
                &bitbox_api::Keypath::from(&keypath),
                if testnet {
                    bitbox_api::pb::btc_pub_request::XPubType::Tpub
                } else {
                    bitbox_api::pb::btc_pub_request::XPubType::Xpub
                },
                false,
            )
            .await
            .map_err(|error| anyhow!("Failed to derive wallet key: {error:?}"))?
            .parse::<Xpub>()
            .map_err(|error| anyhow!("BitBox returned an invalid extended public key: {error}"))?;
        device_xpubs.insert(keypath, xpub);
    }

    let matching_keys = parsed.matching_device_key_indices(fingerprint, &device_xpubs);
    let policy = parsed.prepare(&matching_keys)?;
    ensure_firmware_support(bitbox, &policy, testnet)?;
    Ok(policy)
}

fn ensure_firmware_support(
    bitbox: &PairedBitBox<bitbox_api::runtime::TokioRuntime>,
    policy: &PreparedWalletPolicy,
    testnet: bool,
) -> Result<()> {
    let version = bitbox.version();
    let version = (version.major, version.minor, version.patch);
    if policy.is_taproot() {
        if version < (9, 21, 0) {
            bail!("BitBox firmware 9.21.0 or newer is required for Taproot policies");
        }
    } else if policy.is_miniscript() {
        if version < (9, 15, 0) {
            bail!("BitBox firmware 9.15.0 or newer is required for Miniscript policies");
        }
    } else if version < (9, 19, 0) && !policy.has_standard_multisig_keypath(testnet) {
        bail!("BitBox firmware 9.19.0 or newer is required for this multisig keypath");
    }
    Ok(())
}

fn coin(testnet: bool) -> bitbox_api::pb::BtcCoin {
    if testnet {
        bitbox_api::pb::BtcCoin::Tbtc
    } else {
        bitbox_api::pb::BtcCoin::Btc
    }
}

const MAX_RECEIVE_ADDRESS_INDEX: i64 = 9_999;

fn address_index(index: i64) -> Result<u32> {
    if !(0..=MAX_RECEIVE_ADDRESS_INDEX).contains(&index) {
        bail!("address index must be between 0 and {MAX_RECEIVE_ADDRESS_INDEX}");
    }
    Ok(index as u32)
}

#[cfg(test)]
mod tests {
    use super::address_index;

    #[test]
    fn validates_address_index_before_converting_to_u32() {
        assert_eq!(address_index(0).unwrap(), 0);
        assert_eq!(address_index(9_999).unwrap(), 9_999);
        assert!(address_index(-1).is_err());
        assert!(address_index(10_000).is_err());
    }
}
