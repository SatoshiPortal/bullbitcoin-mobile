//! Public surface of `onion`.
//!
//! The domain and lifecycle remain plain Rust and are directly testable with
//! `cargo test`. A small number of `flutter_rust_bridge` annotations select the
//! generated entrypoint, stream shape, and synchronous predicates.
//!
//! Nothing from `arti_client` crosses this boundary. Every type here is ours,
//! which is what lets the Dart side switch exhaustively and keeps an upstream
//! API change from rippling into the app.

#![deny(unsafe_code)]

pub mod client;
pub mod error;
pub mod session;
pub mod status;

mod socks;

pub use client::TorService;
pub use error::{TorFailure, TorFailureKind, TorResult};
pub use session::{SocksPolicy, TorSession};
pub use status::{Blockage, BlockageKind, TorStatus, TorTransport};
