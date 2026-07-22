/// The Bitcoin network a Silent Payments wallet runs on. Domain mirror of the
/// bwk `SpNetwork` FFI enum; the wire type stays in `data/` behind
/// `SpNetworkMapper`.
enum SpNetwork { bitcoin, signet, testnet, regtest }
