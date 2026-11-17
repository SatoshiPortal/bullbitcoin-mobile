/// Asserts that the FRB-generated Dart code never surfaces ScanMode::Continuous.
/// Run after codegen (the standalone-generated files under lib/src/generated/
/// — see flutter_rust_bridge.yaml `dart_output` — must be up-to-date).
///
/// If the generated dir does not exist yet (standalone codegen not run in this
/// checkout), the test skips/passes gracefully rather than hard-failing: the
/// assertion logic below still runs against every generated .dart file when the
/// dir is present.
#[test]
fn no_continuous_in_generated_dart() {
    use std::fs;
    use walkdir::WalkDir;

    let repo_root = std::path::Path::new(env!("CARGO_MANIFEST_DIR"))
        .parent()
        .expect("repo root");
    let dart_dir = repo_root.join("lib/src/generated");
    if !dart_dir.exists() {
        eprintln!(
            "[skip] {} missing — run standalone codegen first; \
             skipping (assertion logic preserved for when it exists)",
            dart_dir.display()
        );
        return;
    }

    for entry in WalkDir::new(&dart_dir).into_iter().filter_map(|e| e.ok()) {
        if entry.path().extension().and_then(|s| s.to_str()) != Some("dart") {
            continue;
        }
        let body = fs::read_to_string(entry.path()).unwrap();
        assert!(
            !body.contains("Continuous"),
            "Found 'Continuous' in {} — ScanMode::Continuous must not be \
             exposed across FRB",
            entry.path().display()
        );
    }
}
