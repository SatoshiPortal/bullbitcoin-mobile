# Third-Party Notices

The optional mobile Snowflake transport uses the precompiled IPtProxy 5.6.0 distribution. The Rust Arti client remains built from the Cargo lockfile; Go is not part of this repository's build toolchain.

## IPtProxy 5.6.0

- Project: <https://github.com/tladesignz/IPtProxy>
- Source tag: `5.6.0`
- Source commit: `5d9cb01547d507f97f205076e61353de7881c8bc`
- Android coordinate: `com.netzarchitekten:IPtProxy:5.6.0`
- Android AAR SHA-256: `4eab74a060f8ebec908e31d03f0bf9daee386f586e054bd6f0a0a0d907192c32`
- Android Maven signature fingerprint: `34637F8EE098D268BAE1FDD450CCD9677A9373B5`
- iOS device binary SHA-256: `c0d98505601e384e18d182512b8bd83c05960fa2921c4a29bd115f69796b8778`
- iOS simulator binary SHA-256: `a5ba4da9e234d9eb4dfc25a02b6c2aee9b8830125f6018487f29bb16223d9e88`
- IPtProxy wrapper license: MIT

The tag and source commit are not cryptographically signed. The Maven signature exists, but its public key was unavailable during this audit, so the fingerprint above records rather than establishes signer identity. Android and iOS builds independently verify the downloaded binary against the reviewed SHA-256 value and fail on a mismatch.

The upstream binary is not reproducible from source as published: its build scripts use moving Go tooling and its embedded build information contains local paths. This package therefore pins and verifies the reviewed precompiled artifacts rather than claiming source-level reproducibility.

## Bundled Components

IPtProxy embeds multiple transports rather than only Snowflake. IPtProxy 5.6.0 reports Snowflake 2.14.1 and Lyrebird 0.9.0 and also bundles DNSTT. The Go build information embedded in the Android and both iOS binaries agrees: snowflake/v2 v2.14.1, lyrebird v0.0.0-20261006105937-89d54872b176, dnstt v1.20260501.0 and webtunnel v0.0.7, built with go1.27.1. Consult the release's complete dependency set and corresponding license texts before distribution.

- Snowflake: BSD-3-Clause
- Lyrebird: GPL-3.0
- DNSTT and transitive Go modules: see the IPtProxy 5.6.0 source tree and module lock

Because the distributed binary includes GPL-3.0 code even though this package invokes only Snowflake, production distribution requires legal approval and compliance with all applicable source-offer and notice obligations.
