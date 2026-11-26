//! Compile-time-ish enforcement of the SP "user-triggered scan only"
//! invariant on the Rust side.
//!
//! These tests walk `rust/src/` and assert:
//!   * There is EXACTLY ONE call site of `start_scan(` in `rust/src/`, and it
//!     lives inside `pub fn scan_once` in `rust/src/api/sp_account.rs`.
//!   * There are ZERO call sites of `scan_blocks(` in `rust/src/`.
//!
//! Together with `scripts/audit-sp-invariant.sh`, this catches a regression
//! where a future change auto-starts an SP scan from `init`, `load`,
//! `prepare_psbt`, an Electrum-notification handler, or any other path
//! outside the user-driven `ScanSpWalletUsecase`.

use std::fs;
use std::path::{Path, PathBuf};

use walkdir::WalkDir;

fn rust_src_dir() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR")).join("src")
}

fn collect_rs_files(root: &Path) -> Vec<PathBuf> {
    WalkDir::new(root)
        .into_iter()
        .filter_map(|e| e.ok())
        .filter(|e| e.path().extension().and_then(|s| s.to_str()) == Some("rs"))
        .map(|e| e.path().to_path_buf())
        .collect()
}

/// For a given source file and byte offset, return the most recent
/// `pub fn <name>` signature line that precedes the offset, if any.
fn enclosing_pub_fn(body: &str, needle_offset: usize) -> Option<String> {
    let preceding = &body[..needle_offset];
    let mut current: Option<String> = None;
    for line in preceding.lines() {
        let trimmed = line.trim_start();
        if trimmed.starts_with("pub fn ") {
            current = Some(trimmed.to_string());
        }
    }
    current
}

#[test]
fn start_scan_has_exactly_one_call_site_in_scan_once() {
    let src = rust_src_dir();
    assert!(src.exists(), "rust/src missing");

    let mut hits: Vec<(PathBuf, usize, String)> = Vec::new();
    for file in collect_rs_files(&src) {
        let body = fs::read_to_string(&file).unwrap_or_default();
        for (idx, _) in body.match_indices("start_scan(") {
            let enclosing = enclosing_pub_fn(&body, idx).unwrap_or_default();
            hits.push((file.clone(), idx, enclosing));
        }
    }

    assert_eq!(
        hits.len(),
        1,
        "expected exactly 1 start_scan( call site in rust/src/, \
         found {}: {:#?}. SP rescan must be user-triggered only.",
        hits.len(),
        hits
    );

    let (file, _, enclosing) = &hits[0];
    let expected = rust_src_dir().join("api").join("sp_account.rs");
    assert_eq!(
        file,
        &expected,
        "the single start_scan( call site must live in {}, found {}",
        expected.display(),
        file.display()
    );
    assert!(
        enclosing.starts_with("pub fn scan_once"),
        "the single start_scan( call site must be inside `pub fn scan_once`, \
         found enclosing fn: `{enclosing}`",
    );
}

#[test]
fn no_scan_blocks_calls_in_rust_src() {
    let src = rust_src_dir();
    assert!(src.exists(), "rust/src missing");

    let mut offenders: Vec<PathBuf> = Vec::new();
    for file in collect_rs_files(&src) {
        let body = fs::read_to_string(&file).unwrap_or_default();
        if body.contains("scan_blocks(") {
            offenders.push(file);
        }
    }

    assert!(
        offenders.is_empty(),
        "scan_blocks( must not be called from rust/src/. Offenders: {offenders:#?}",
    );
}
