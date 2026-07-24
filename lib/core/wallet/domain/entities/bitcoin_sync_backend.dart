/// The mechanism a Bitcoin wallet uses to discover and sync its chain data.
///
/// Persisted per-wallet on [WalletMetadataModel]. Every wallet created before
/// this field existed is migrated to [electrum] (schema 13 -> 14) since that
/// was the only backend available at the time. [compactBlockFilters] is
/// reserved for wallets that opt into BIP157/158 compact block filter sync;
/// no CBF sync behaviour is wired up yet — this enum only carries the
/// persisted choice.
enum BitcoinSyncBackend { electrum, compactBlockFilters }
