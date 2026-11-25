use std::str::FromStr;
use std::time::{SystemTime, UNIX_EPOCH};

use bark::actions::lightning::pay::LightningSendState;
use bark::actions::lightning::receive::{LightningReceiveState, Progress};
use bark::ark::VtxoId;
use bark::ark::lightning::{Invoice, PaymentHash};
use bark::ark::vtxo::VtxoRef;
use bark::movement::{Movement, MovementStatus, PaymentMethod};
use bark::payment_request::PaymentRequest;
use bark::round::RoundFlowKind;
use bark::{FeeEstimate, Wallet};
use bitcoin::Amount;
use flutter_rust_bridge::frb;

use super::wallet::ScuttleWallet;

/// Amounts are in sats. For sends, `gross_sats` is what leaves the wallet and `net_sats` what
/// the recipient gets; for receives and refreshes, `net_sats` is what the wallet ends up with.
pub struct ScuttleFeeEstimate {
    pub gross_sats: u64,
    pub fee_sats: u64,
    pub net_sats: u64,
    pub vtxo_ids: Vec<String>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ScuttlePaymentKind {
    Ark,
    Bolt11,
    Bitcoin,
}

pub struct ScuttlePaymentOption {
    pub kind: ScuttlePaymentKind,
    /// False when the native parser flagged the option (wrong network, bad amount, ...).
    pub valid: bool,
}

/// Only the kinds the app can execute are listed; other native methods are dropped.
pub struct ScuttlePaymentRequest {
    pub amount_sats: Option<u64>,
    pub options: Vec<ScuttlePaymentOption>,
}

pub struct ScuttleOnchainSend {
    pub txid: String,
    pub movement_id: u32,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ScuttleLightningSendStatus {
    Unknown,
    InProgress,
    Paid,
}

pub struct ScuttleLightningSend {
    pub payment_hash: String,
    pub amount_sats: u64,
    pub fee_sats: u64,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ScuttleLightningReceiveStage {
    AwaitingPayment,
    HtlcsReady,
    PreimageRevealed,
    Delivering,
}

pub struct ScuttleLightningReceive {
    pub payment_hash: String,
    pub invoice: String,
    pub amount_sats: Option<u64>,
    pub stage: ScuttleLightningReceiveStage,
}

pub struct ScuttleLightningInvoice {
    pub invoice: String,
    pub payment_hash: String,
}

/// Outcome of one non-waiting claim pass over every pending receive.
pub struct ScuttleClaimReport {
    pub settled: u32,
    pub pending: u32,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ScuttleRoundFlow {
    DelegatedPending,
    Pending,
    Ongoing,
    AwaitingConfirmations,
    Failed,
    Canceled,
}

pub struct ScuttleRoundState {
    pub id: u32,
    pub flow: ScuttleRoundFlow,
    pub input_vtxo_ids: Vec<String>,
    pub input_sats: u64,
    pub pending_sats: u64,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ScuttleMovementStatus {
    Pending,
    Successful,
    Failed,
    Canceled,
}

pub struct ScuttleMovement {
    pub id: u32,
    pub subsystem: String,
    pub kind: String,
    pub status: ScuttleMovementStatus,
    pub intended_sats: i64,
    pub effective_sats: i64,
    pub fee_sats: u64,
    pub created_at: i64,
    pub updated_at: i64,
    pub completed_at: Option<i64>,
}

impl ScuttleWallet {
    pub async fn estimate_ark_payment_fee(
        &self,
        amount_sats: u64,
    ) -> Result<ScuttleFeeEstimate, String> {
        let amount = amount(amount_sats)?;
        let guard = self.wallet.lock().await;
        let wallet = guard.as_ref().ok_or("Wallet closed")?;
        wallet
            .estimate_arkoor_payment_fee(amount)
            .await
            .map(fee_estimate)
            .map_err(|_| "Cannot estimate Ark payment fee".into())
    }

    pub async fn estimate_lightning_payment_fee(
        &self,
        invoice: String,
        amount_sats: u64,
    ) -> Result<ScuttleFeeEstimate, String> {
        let amount = amount(amount_sats)?;
        let invoice = invoice_for(&invoice, amount)?;
        let guard = self.wallet.lock().await;
        let wallet = guard.as_ref().ok_or("Wallet closed")?;
        wallet
            .estimate_invoice_payment_fee(&invoice, amount)
            .await
            .map(fee_estimate)
            .map_err(|_| "Cannot estimate Lightning payment fee".into())
    }

    pub async fn estimate_onchain_send_fee(
        &self,
        address: String,
        amount_sats: u64,
    ) -> Result<ScuttleFeeEstimate, String> {
        let amount = amount(amount_sats)?;
        let guard = self.wallet.lock().await;
        let wallet = guard.as_ref().ok_or("Wallet closed")?;
        let address = bitcoin_address(wallet, &address).await?;
        wallet
            .estimate_send_onchain(&address, amount)
            .await
            .map(fee_estimate)
            .map_err(|_| "Cannot estimate on-chain send fee".into())
    }

    pub async fn estimate_lightning_receive_fee(
        &self,
        amount_sats: u64,
    ) -> Result<ScuttleFeeEstimate, String> {
        let amount = amount(amount_sats)?;
        let guard = self.wallet.lock().await;
        let wallet = guard.as_ref().ok_or("Wallet closed")?;
        wallet
            .estimate_lightning_receive_fee(amount)
            .await
            .map(fee_estimate)
            .map_err(|_| "Cannot estimate Lightning receive fee".into())
    }

    pub async fn estimate_refresh_fee(
        &self,
        vtxo_ids: Vec<String>,
    ) -> Result<ScuttleFeeEstimate, String> {
        let ids = parse_vtxo_ids(&vtxo_ids)?;
        let guard = self.wallet.lock().await;
        let wallet = guard.as_ref().ok_or("Wallet closed")?;
        let vtxos = wallet
            .get_full_vtxos(ids)
            .await
            .map_err(|_| "Cannot read VTXOs")?;
        wallet
            .estimate_refresh_fee(&vtxos)
            .await
            .map(fee_estimate)
            .map_err(|_| "Cannot estimate refresh fee".into())
    }

    /// Parses a payment request and keeps only Ark, BOLT11 and bitcoin options. The native
    /// parser may resolve other forms (LNURL, Lightning address) over the network.
    pub async fn parse_payment_request(
        &self,
        payment: String,
    ) -> Result<ScuttlePaymentRequest, String> {
        let guard = self.wallet.lock().await;
        let wallet = guard.as_ref().ok_or("Wallet closed")?;
        let request = wallet
            .parse_payment_request(payment.trim())
            .await
            .map_err(|_| "Invalid payment request")?;
        Ok(project_request(&request))
    }

    /// Starts a BOLT11 payment without waiting for settlement and returns its payment hash. A
    /// failure after native admission must be treated as an unknown outcome, not retried.
    pub async fn pay_lightning_invoice(
        &self,
        invoice: String,
        amount_sats: u64,
    ) -> Result<String, String> {
        let amount = amount(amount_sats)?;
        let invoice = invoice_for(&invoice, amount)?;
        let hash = invoice.payment_hash();
        let guard = self.wallet.lock().await;
        let wallet = guard.as_ref().ok_or("Wallet closed")?;
        wallet
            .pay_lightning_invoice(invoice, Some(amount), false)
            .await
            .map(|_| hash.to_string())
            .map_err(|_| "Payment outcome unknown".into())
    }

    /// Offboards `amount_sats` to a bitcoin address. A failure after native admission must be
    /// treated as an unknown outcome, not retried.
    pub async fn send_onchain(
        &self,
        address: String,
        amount_sats: u64,
    ) -> Result<ScuttleOnchainSend, String> {
        let amount = amount(amount_sats)?;
        let guard = self.wallet.lock().await;
        let wallet = guard.as_ref().ok_or("Wallet closed")?;
        let address = bitcoin_address(wallet, &address).await?;
        wallet
            .send_onchain(address, amount)
            .await
            .map(|result| ScuttleOnchainSend {
                txid: result.txid.to_string(),
                movement_id: result.movement_id.0,
            })
            .map_err(|_| "Payment outcome unknown".into())
    }

    /// Stores a fresh BOLT11 invoice and returns it; the claim happens in a later pass.
    pub async fn create_lightning_invoice(
        &self,
        amount_sats: u64,
    ) -> Result<ScuttleLightningInvoice, String> {
        let amount = amount(amount_sats)?;
        let guard = self.wallet.lock().await;
        let wallet = guard.as_ref().ok_or("Wallet closed")?;
        wallet
            .bolt11_invoice(amount, None, None)
            .await
            .map(|invoice| ScuttleLightningInvoice {
                payment_hash: PaymentHash::from(&invoice).to_string(),
                invoice: invoice.to_string(),
            })
            .map_err(|_| "Cannot create Lightning invoice".into())
    }

    pub async fn pending_lightning_receives(&self) -> Result<Vec<ScuttleLightningReceive>, String> {
        let guard = self.wallet.lock().await;
        let wallet = guard.as_ref().ok_or("Wallet closed")?;
        let pending = wallet
            .pending_lightning_receives()
            .await
            .map_err(|_| "Cannot read Lightning receives")?;
        Ok(pending
            .into_iter()
            .map(|receive| ScuttleLightningReceive {
                payment_hash: receive.payment_hash.to_string(),
                amount_sats: receive
                    .invoice
                    .amount_milli_satoshis()
                    .map(|msat| msat / 1000),
                invoice: receive.invoice.to_string(),
                stage: match receive.progress {
                    Progress::AwaitingPayment => ScuttleLightningReceiveStage::AwaitingPayment,
                    Progress::HtlcsReady(_) => ScuttleLightningReceiveStage::HtlcsReady,
                    Progress::PreimageRevealed(_) => ScuttleLightningReceiveStage::PreimageRevealed,
                    Progress::Delivering(_) => ScuttleLightningReceiveStage::Delivering,
                },
            })
            .collect())
    }

    pub async fn pending_lightning_sends(&self) -> Result<Vec<ScuttleLightningSend>, String> {
        let guard = self.wallet.lock().await;
        let wallet = guard.as_ref().ok_or("Wallet closed")?;
        let pending = wallet
            .pending_lightning_sends()
            .await
            .map_err(|_| "Cannot read Lightning sends")?;
        Ok(pending
            .into_iter()
            .map(|send| ScuttleLightningSend {
                payment_hash: send.invoice.payment_hash().to_string(),
                amount_sats: send.payment_amount.to_sat(),
                fee_sats: send.fee.to_sat(),
            })
            .collect())
    }

    /// Drives every pending Lightning receive once without waiting.
    pub async fn claim_lightning_receives(&self) -> Result<ScuttleClaimReport, String> {
        let guard = self.wallet.lock().await;
        let wallet = guard.as_ref().ok_or("Wallet closed")?;
        let states = wallet
            .try_claim_all_lightning_receives(false)
            .await
            .map_err(|_| "Cannot claim Lightning receives")?;
        let settled = states
            .iter()
            .filter(|state| matches!(state, LightningReceiveState::Settled(_)))
            .count();
        Ok(ScuttleClaimReport {
            settled: settled as u32,
            pending: (states.len() - settled) as u32,
        })
    }

    pub async fn lightning_send_status(
        &self,
        payment_hash: String,
    ) -> Result<ScuttleLightningSendStatus, String> {
        let hash = PaymentHash::from_str(&payment_hash).map_err(|_| "Invalid payment hash")?;
        let guard = self.wallet.lock().await;
        let wallet = guard.as_ref().ok_or("Wallet closed")?;
        wallet
            .lightning_send_state(hash)
            .await
            .map(|state| match state {
                LightningSendState::Unknown => ScuttleLightningSendStatus::Unknown,
                LightningSendState::InProgress(_) => ScuttleLightningSendStatus::InProgress,
                LightningSendState::Paid(_) => ScuttleLightningSendStatus::Paid,
            })
            .map_err(|_| "Cannot read Lightning send state".into())
    }

    /// Spendable VTXOs the wallet wants to refresh now.
    pub async fn vtxos_to_refresh(&self) -> Result<Vec<String>, String> {
        let guard = self.wallet.lock().await;
        let wallet = guard.as_ref().ok_or("Wallet closed")?;
        wallet
            .get_vtxos_to_refresh()
            .await
            .map(|vtxos| vtxos.iter().map(|v| v.vtxo_id().to_string()).collect())
            .map_err(|_| "Cannot read VTXOs to refresh".into())
    }

    /// Joins the next round in delegated mode and returns the stored round id, or `None` when
    /// nothing needed refreshing. A failure after native admission is an unknown outcome.
    pub async fn refresh_vtxos_delegated(
        &self,
        vtxo_ids: Vec<String>,
    ) -> Result<Option<u32>, String> {
        let ids = parse_vtxo_ids(&vtxo_ids)?;
        let guard = self.wallet.lock().await;
        let wallet = guard.as_ref().ok_or("Wallet closed")?;
        wallet
            .refresh_vtxos_delegated(ids)
            .await
            .map(|state| state.map(|s| s.id().0))
            .map_err(|_| "Refresh outcome unknown".into())
    }

    pub async fn pending_round_states(&self) -> Result<Vec<ScuttleRoundState>, String> {
        let guard = self.wallet.lock().await;
        let wallet = guard.as_ref().ok_or("Wallet closed")?;
        let states = wallet
            .pending_round_states()
            .await
            .map_err(|_| "Cannot read pending rounds")?;
        Ok(states
            .iter()
            .map(|stored| {
                let state = stored.state();
                let inputs = &state.participation().inputs;
                ScuttleRoundState {
                    id: stored.id().0,
                    flow: round_flow(state.flow_kind()),
                    input_vtxo_ids: inputs.iter().map(|v| v.id().to_string()).collect(),
                    input_sats: inputs.iter().map(|v| v.amount().to_sat()).sum(),
                    pending_sats: state.pending_balance().to_sat(),
                }
            })
            .collect())
    }

    pub async fn progress_pending_rounds(&self) -> Result<(), String> {
        let guard = self.wallet.lock().await;
        let wallet = guard.as_ref().ok_or("Wallet closed")?;
        wallet
            .progress_pending_rounds(None)
            .await
            .map_err(|_| "Cannot progress pending rounds".into())
    }

    /// Unix seconds of the next round start announced by the server.
    pub async fn next_round_start_time(&self) -> Result<u64, String> {
        let guard = self.wallet.lock().await;
        let wallet = guard.as_ref().ok_or("Wallet closed")?;
        let time = wallet
            .next_round_start_time()
            .await
            .map_err(|_| "Cannot read next round time")?;
        unix_secs(time)
    }

    /// Movements ordered from newest to oldest, from the local database.
    pub async fn history(&self) -> Result<Vec<ScuttleMovement>, String> {
        let guard = self.wallet.lock().await;
        let wallet = guard.as_ref().ok_or("Wallet closed")?;
        wallet
            .history()
            .await
            .map(|movements| movements.iter().map(project_movement).collect())
            .map_err(|_| "Cannot read history".into())
    }
}

#[frb(ignore)]
fn amount(sats: u64) -> Result<Amount, String> {
    if sats == 0 {
        return Err("Invalid payment amount".into());
    }
    Ok(Amount::from_sat(sats))
}

#[frb(ignore)]
fn fee_estimate(estimate: FeeEstimate) -> ScuttleFeeEstimate {
    ScuttleFeeEstimate {
        gross_sats: estimate.gross_amount.to_sat(),
        fee_sats: estimate.fee.to_sat(),
        net_sats: estimate.net_amount.to_sat(),
        vtxo_ids: estimate
            .vtxos_spent
            .iter()
            .map(|id| id.to_string())
            .collect(),
    }
}

#[frb(ignore)]
fn parse_vtxo_ids(ids: &[String]) -> Result<Vec<VtxoId>, String> {
    if ids.is_empty() {
        return Err("Invalid VTXO selection".into());
    }
    ids.iter()
        .map(|id| VtxoId::from_str(id).map_err(|_| "Invalid VTXO selection".to_string()))
        .collect()
}

/// Accepts only a BOLT11 invoice whose amount, if fixed, equals `amount`.
#[frb(ignore)]
fn invoice_for(text: &str, amount: Amount) -> Result<Invoice, String> {
    let invoice = Invoice::from_str(text.trim()).map_err(|_| "Invalid Lightning invoice")?;
    if !matches!(invoice, Invoice::Bolt11(_)) {
        return Err("Invalid Lightning invoice".into());
    }
    invoice
        .get_payment_amount(Some(amount))
        .map_err(|_| "Invalid payment amount")?;
    Ok(invoice)
}

#[frb(ignore)]
async fn bitcoin_address(wallet: &Wallet, text: &str) -> Result<bitcoin::Address, String> {
    let network = wallet
        .network()
        .await
        .map_err(|_| "Cannot read wallet network")?;
    bitcoin::Address::from_str(text.trim())
        .map_err(|_| "Invalid bitcoin address")?
        .require_network(network)
        .map_err(|_| "Invalid bitcoin address".into())
}

#[frb(ignore)]
fn classify(method: &PaymentMethod) -> Option<ScuttlePaymentKind> {
    match method {
        PaymentMethod::Ark(_) => Some(ScuttlePaymentKind::Ark),
        PaymentMethod::Invoice(Invoice::Bolt11(_)) => Some(ScuttlePaymentKind::Bolt11),
        PaymentMethod::Bitcoin(_) => Some(ScuttlePaymentKind::Bitcoin),
        _ => None,
    }
}

#[frb(ignore)]
fn project_request(request: &PaymentRequest) -> ScuttlePaymentRequest {
    ScuttlePaymentRequest {
        amount_sats: request.amount.map(|a| a.to_sat()),
        options: request
            .options
            .iter()
            .filter_map(|option| {
                classify(&option.method).map(|kind| ScuttlePaymentOption {
                    kind,
                    valid: option.errors.is_empty(),
                })
            })
            .collect(),
    }
}

#[frb(ignore)]
fn round_flow(kind: RoundFlowKind) -> ScuttleRoundFlow {
    match kind {
        RoundFlowKind::DelegatedPending => ScuttleRoundFlow::DelegatedPending,
        RoundFlowKind::Pending => ScuttleRoundFlow::Pending,
        RoundFlowKind::Ongoing => ScuttleRoundFlow::Ongoing,
        RoundFlowKind::AwaitingConfirmations => ScuttleRoundFlow::AwaitingConfirmations,
        RoundFlowKind::Failed => ScuttleRoundFlow::Failed,
        RoundFlowKind::Canceled => ScuttleRoundFlow::Canceled,
    }
}

#[frb(ignore)]
fn unix_secs(time: SystemTime) -> Result<u64, String> {
    time.duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs())
        .map_err(|_| "Invalid round time".into())
}

#[frb(ignore)]
fn project_movement(movement: &Movement) -> ScuttleMovement {
    ScuttleMovement {
        id: movement.id.0,
        subsystem: movement.subsystem.name.clone(),
        kind: movement.subsystem.kind.clone(),
        status: match movement.status {
            MovementStatus::Pending => ScuttleMovementStatus::Pending,
            MovementStatus::Successful => ScuttleMovementStatus::Successful,
            MovementStatus::Failed => ScuttleMovementStatus::Failed,
            MovementStatus::Canceled => ScuttleMovementStatus::Canceled,
        },
        intended_sats: movement.intended_balance.to_sat(),
        effective_sats: movement.effective_balance.to_sat(),
        fee_sats: movement.offchain_fee.to_sat(),
        created_at: movement.time.created_at.timestamp(),
        updated_at: movement.time.updated_at.timestamp(),
        completed_at: movement.time.completed_at.map(|t| t.timestamp()),
    }
}

#[cfg(test)]
mod tests {
    use std::time::Duration;

    use bark::ark::VtxoId;

    use super::*;

    const ADDRESS: &str = "bcrt1qw508d6qejxtdg4y5r3zarvary0c5xw7kygt080";

    #[test]
    fn zero_amounts_are_rejected_without_contacting_the_server() {
        assert_eq!(amount(0), Err("Invalid payment amount".to_string()));
        assert_eq!(amount(330), Ok(Amount::from_sat(330)));
    }

    #[test]
    fn fee_estimate_keeps_gross_fee_net_and_inputs() {
        let id = VtxoId::from_str(&format!("{}:1", "00".repeat(32))).expect("vtxo id");
        let projected = fee_estimate(FeeEstimate::new(
            Amount::from_sat(1_010),
            Amount::from_sat(10),
            Amount::from_sat(1_000),
            vec![id],
        ));
        assert_eq!(
            (projected.gross_sats, projected.fee_sats, projected.net_sats),
            (1_010, 10, 1_000)
        );
        assert_eq!(projected.vtxo_ids, vec![id.to_string()]);
    }

    #[test]
    fn vtxo_selection_is_non_empty_and_well_formed() {
        assert!(parse_vtxo_ids(&[]).is_err());
        assert!(parse_vtxo_ids(&["nope".into()]).is_err());
        let id = format!("{}:0", "ab".repeat(32));
        let parsed = parse_vtxo_ids(std::slice::from_ref(&id)).expect("valid selection");
        assert_eq!(parsed[0].to_string(), id);
    }

    #[test]
    fn only_executable_payment_kinds_are_classified() {
        let bitcoin = PaymentMethod::Bitcoin(bitcoin::Address::from_str(ADDRESS).expect("address"));
        assert_eq!(classify(&bitcoin), Some(ScuttlePaymentKind::Bitcoin));
        assert_eq!(classify(&PaymentMethod::Custom("x".into())), None);
    }

    #[test]
    fn request_projection_keeps_amount_and_flags_invalid_options() {
        let method = PaymentMethod::Bitcoin(bitcoin::Address::from_str(ADDRESS).expect("address"));
        let request = PaymentRequest {
            amount: Some(Amount::from_sat(2_000)),
            label: None,
            message: None,
            options: vec![
                bark::AvailablePaymentMethod {
                    method: method.clone(),
                    errors: vec![bark::PaymentMethodParsingError::NetworkMismatch],
                },
                bark::AvailablePaymentMethod {
                    method: PaymentMethod::Custom("x".into()),
                    errors: vec![],
                },
            ],
        };
        let projected = project_request(&request);
        assert_eq!(projected.amount_sats, Some(2_000));
        assert_eq!(projected.options.len(), 1);
        assert_eq!(projected.options[0].kind, ScuttlePaymentKind::Bitcoin);
        assert!(!projected.options[0].valid);
    }

    #[test]
    fn payment_hash_must_be_64_hex_characters() {
        assert!(PaymentHash::from_str("abcd").is_err());
        assert!(PaymentHash::from_str(&"0f".repeat(32)).is_ok());
    }

    #[test]
    fn round_time_is_unix_seconds_and_rejects_pre_epoch() {
        assert_eq!(unix_secs(UNIX_EPOCH + Duration::from_secs(42)), Ok(42));
        assert!(unix_secs(UNIX_EPOCH - Duration::from_secs(1)).is_err());
    }

    #[test]
    fn round_flows_map_one_to_one() {
        assert_eq!(
            round_flow(RoundFlowKind::AwaitingConfirmations),
            ScuttleRoundFlow::AwaitingConfirmations
        );
        assert_eq!(
            round_flow(RoundFlowKind::DelegatedPending),
            ScuttleRoundFlow::DelegatedPending
        );
    }

    #[test]
    fn movement_projection_keeps_ids_status_amounts_and_times() {
        let movement: Movement = serde_json::from_value(serde_json::json!({
            "id": 7,
            "status": MovementStatus::Successful.as_str(),
            "subsystem": { "name": "bark.arkoor", "kind": "send" },
            "metadata": {},
            "intended_balance": -1_000,
            "effective_balance": -1_010,
            "offchain_fee": 10,
            "sent_to": [],
            "received_on": [],
            "input_vtxos": [],
            "output_vtxos": [],
            "exited_vtxos": [],
            "time": {
                "created_at": "2026-01-01T00:00:00+00:00",
                "updated_at": "2026-01-01T00:00:10+00:00",
                "completed_at": "2026-01-01T00:00:20+00:00"
            }
        }))
        .expect("movement json");
        let projected = project_movement(&movement);
        assert_eq!(projected.id, 7);
        assert_eq!(projected.status, ScuttleMovementStatus::Successful);
        assert_eq!(
            (projected.subsystem.as_str(), projected.kind.as_str()),
            ("bark.arkoor", "send")
        );
        assert_eq!(
            (projected.intended_sats, projected.effective_sats),
            (-1_000, -1_010)
        );
        assert_eq!(projected.fee_sats, 10);
        assert_eq!(projected.updated_at - projected.created_at, 10);
        assert_eq!(projected.completed_at, Some(projected.created_at + 20));
    }
}
