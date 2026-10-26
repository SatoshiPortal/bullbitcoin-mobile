/// Time Tor gets to connect to a destination through any embedded listener, onion services included.
///
/// Outer operation deadlines leave headroom for Tor to return its own failure.
const torConnectBudget = Duration(seconds: 60);

/// Deadline for work that waits on a Tor connect: [torConnectBudget] plus 10%.
///
/// Callers derive their own timeouts from it so Tor's budget always expires first and its reason reaches them, instead of a bare timeout of their own.
final torConnectDeadline = torConnectBudget * 1.1;
