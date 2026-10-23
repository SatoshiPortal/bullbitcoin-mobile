/// Tor connect budget for each onion connect through a RecoverBull session.
///
/// Measured on cold installs, successful first contacts took up to 34 seconds while failed ones never recovered within the budget, so 40 seconds keeps every observed success and lets the user reach New route quickly.
const keyServerConnectBudget = Duration(seconds: 40);

/// Upper bound on one whole key-server probe, 10% above [keyServerConnectBudget].
///
/// Deriving it keeps Tor's own reason first whatever the budget becomes: the deadline only fires when Tor connected but the server never answered.
final keyServerProbeDeadline = keyServerConnectBudget * 1.1;
