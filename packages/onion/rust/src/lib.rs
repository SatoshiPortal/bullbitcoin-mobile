//! Embedded Tor client and loopback SOCKS5 proxy, built on Arti.
//!
//! **This is not an official Tor Project product.** Tor is a trademark of The
//! Tor Project; all rights reserved. See <https://torproject.org>. This
//! software is not endorsed or sponsored by, or affiliated with, the Tor
//! Project.
//!
//! # Design notes
//!
//! - Depends on `arti-client` and `tor-socksproto` only. It does **not**
//!   depend on the `arti` crate, whose entire API surface has been marked
//!   experimental since arti 2.0.0.
//! - Exposes only types defined in this crate, so an upstream change is
//!   absorbed here rather than in the app.
//! - The SOCKS port is the integration point with RecoverBull's Dart HTTP
//!   client, which already supports a SOCKS5 endpoint.

#![warn(missing_docs)]

pub mod api;

// Layout and ordering come from the `flutter_rust_bridge_codegen integrate`
// template. The `#[allow]` is ours: the generated FFI glue is machine-written
// and undocumented, so the lint above does not apply to it. `deny(unsafe_code)`
// lives in `api/mod.rs`, where it constrains code we actually write.
#[allow(clippy::all, missing_docs, unsafe_code)]
mod frb_generated;
