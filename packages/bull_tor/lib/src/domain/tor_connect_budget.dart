/// Time Tor gets to connect to a destination through any embedded listener, onion services included.
///
/// Measured on cold installs, successful first onion contacts took up to 34 seconds while failed ones never recovered within the budget, so 40 seconds keeps every observed success without making a failure wait much longer.
const torConnectBudget = Duration(seconds: 60);

/// Deadline for work that waits on a Tor connect: [torConnectBudget] plus 10%.
///
/// Callers derive their own timeouts from it so Tor's budget always expires first and its reason reaches them, instead of a bare timeout of their own.
final torConnectDeadline = torConnectBudget * 1.1;
