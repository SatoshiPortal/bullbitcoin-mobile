/// Durable relay evidence for a locally staged CBF transaction.
/// A submission interrupted before its acknowledgement is persisted remains
/// uncertain: it must never be presented as safe to cancel after a restart.
enum CbfRelayState { notBroadcast, submitting, relayed, canceled }
