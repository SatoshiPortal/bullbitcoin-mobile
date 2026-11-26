use crate::api::types::RegtestDefaults;

/// Fetch default regtest infrastructure addresses from minta.pythcoiner.dev.
///
/// This is the one function in the SP surface that is async instead of
/// pushing its result through the single `StreamSink<SpNotification>` sink.
/// It runs during SP setup to prefill the URLs used to create the SP account,
/// so it fires before any `SpAccount` exists and therefore before that
/// notification sink exists. There is no sink to push to yet. Leaving off
/// `#[frb(sync)]` makes FRB return a Future so the blocking `ureq` fetch runs
/// on an FRB worker thread rather than the caller isolate.
pub fn get_regtest_defaults() -> RegtestDefaults {
    let url = "http://minta.pythcoiner.dev/api/status";

    let response = match ureq::get(url).call() {
        Ok(r) => r,
        Err(e) => {
            log::warn!("failed to fetch regtest defaults: {e}");
            return RegtestDefaults {
                is_ok: false,
                error: format!("HTTP request failed: {e}"),
                blindbit_url: String::new(),
                p2p_node: String::new(),
                electrum_url: String::new(),
            };
        }
    };

    let body: String = match response.into_string() {
        Ok(s) => s,
        Err(e) => {
            log::warn!("failed to read regtest defaults response: {e}");
            return RegtestDefaults {
                is_ok: false,
                error: format!("Failed to read response: {e}"),
                blindbit_url: String::new(),
                p2p_node: String::new(),
                electrum_url: String::new(),
            };
        }
    };

    let json: serde_json::Value = match serde_json::from_str(&body) {
        Ok(v) => v,
        Err(e) => {
            log::warn!("failed to parse regtest defaults JSON: {e}");
            return RegtestDefaults {
                is_ok: false,
                error: format!("JSON parse failed: {e}"),
                blindbit_url: String::new(),
                p2p_node: String::new(),
                electrum_url: String::new(),
            };
        }
    };

    let blindbit_connect = json["blindbit_connect"].as_str().unwrap_or_default();
    let p2p_connect = json["p2p_connect"].as_str().unwrap_or_default();
    let electrum_connect = json["electrum_connect"].as_str().unwrap_or_default();

    if blindbit_connect.is_empty() || p2p_connect.is_empty() {
        return RegtestDefaults {
            is_ok: false,
            error: "Missing fields in API response".to_string(),
            blindbit_url: String::new(),
            p2p_node: String::new(),
            electrum_url: String::new(),
        };
    }

    RegtestDefaults {
        is_ok: true,
        error: String::new(),
        blindbit_url: format!("http://{blindbit_connect}"),
        p2p_node: p2p_connect.to_string(),
        electrum_url: electrum_connect.to_string(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    #[ignore] // run with: SP_NETWORK_TESTS=1 cargo test -- --ignored
    fn fetch_regtest_defaults_smoke() {
        if std::env::var("SP_NETWORK_TESTS").is_err() {
            return;
        }
        let r = get_regtest_defaults();
        assert!(r.is_ok, "minta unreachable: {}", r.error);
        assert!(!r.blindbit_url.is_empty());
    }
}
