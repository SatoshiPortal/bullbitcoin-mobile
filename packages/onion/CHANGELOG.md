## 0.1.0

- Add an embedded Arti client and loopback SOCKS5 proxy for `.onion` traffic.
- Expose bootstrap progress, blockage diagnostics, reachability probes, dormancy, and deterministic shutdown through flutter_rust_bridge.
- Add a checksum-verified IPtProxy 5.5.1 Snowflake transport on Android and iOS, with unmanaged Arti bridge configuration and process-wide native leases.
- Add `TorSession` listeners backed by Arti isolated clients so application streams from separate sessions never share circuits.
- Support Android, iOS, Linux, macOS, and Windows through Cargokit.
