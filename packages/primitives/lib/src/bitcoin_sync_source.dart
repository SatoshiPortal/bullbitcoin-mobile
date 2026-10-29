/// Bitcoin history transport. Compact block filters observe confirmed blocks
/// only; selecting them never authorizes an Electrum history fallback.
enum BitcoinSyncSource { electrum, compactBlockFilters }
