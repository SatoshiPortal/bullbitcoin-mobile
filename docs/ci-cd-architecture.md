# CI/CD Architecture for Bull Bitcoin Mobile E2E Tests

## Research Date: April 2026

## The ARM64 Problem — And Its Solution

### Problem
Our APK is arm64-only due to the Cargokit patch that restricts Rust FFI
compilation to `arm64-v8a`. Without this patch, Cargokit builds for armv7 +
arm64 + x86 + x86_64, consuming ~80GB of disk space.

The question: can we run this arm64-only APK in CI without real ARM hardware?

### Answer: YES — API 34+ x86_64 Emulator Has ARM ABI Translation

Starting with Android API 34, Google's x86_64 emulator system images include
`libndk_translation` (the successor to Intel's Houdini), which translates
ARM64 native code to x86_64 at runtime. This means:

- An **arm64-only APK installs and runs** on an x86_64 emulator with API 34+
- Performance is ~70-80% of native (acceptable for E2E tests)
- No need for ARM hardware, device farms, or special runners

**Confirmed by:**
- [ReactiveCircus/android-emulator-runner#458](https://github.com/ReactiveCircus/android-emulator-runner/issues/458) — working example with API 35
- [XDA Forums](https://xdaforums.com/t/4713598) — API 34, 35, 36 all support ABI translation
- [Google's Android 11 blog post](https://android-developers.googleblog.com/2020/03/run-arm-apps-on-android-emulator.html) — feature origin

### Critical Configuration
```yaml
api-level: 35          # Must be 34+
target: google_apis    # Required for ABI translation
arch: x86_64           # The host arch (NOT arm64-v8a)
```

## Architecture: Two-Job Pipeline

```
PR opened
  |
  v
[Job 1: BUILD] ---- 4-core Linux runner ($0.012/min)
  |  - Rust compilation with sccache
  |  - Flutter build + codegen
  |  - Cargokit arm64-only patch
  |  - patrol build android
  |  - Upload APKs as artifacts
  v
[Job 2: TEST] ----- 2-core Linux runner ($0.006/min)
  |  - Docker: Nigiri (bitcoind, electrs, esplora)
  |  - KVM: Android emulator (API 35, x86_64, ARM translation)
  |  - Install APKs
  |  - Run Patrol instrumentation tests
  |  - Capture failure artifacts
  v
Results reported on PR
```

## Why KVM + Docker Work Simultaneously

- **KVM** is hardware-assisted virtualization via `/dev/kvm` kernel module
- **Docker** uses Linux namespaces and cgroups (no hardware virtualization)
- They are orthogonal technologies that coexist without conflict
- GitHub Actions ubuntu-latest has supported KVM since April 2024

## Options Evaluated and Rejected

### Firebase Test Lab
- **Verdict: REJECTED**
- Flutter's own team declared it "too flaky" and removed their FTL tests
  ([flutter/flutter#63419](https://github.com/flutter/flutter/issues/63419))
- Known issues: timeouts, preprocessing errors, WAKE_LOCK exceptions,
  random test failures
- Multiple open issues: #42349, #36501, #46132, #85728, #123320

### emulator.wtf
- **Verdict: NOT NEEDED (for now)**
- Pricing: $0 base + $2/emulator-hour (Startup plan)
- Excellent stability and speed (2-5x faster than Firebase)
- But: runs x86_64 emulators only — unclear if they have ARM translation
- Our current approach (GitHub Actions + KVM emulator) is free/cheap
- **Escalation path**: if our emulator proves flaky, emulator.wtf at ~$10-20/month
  for light usage would be a good upgrade

### AWS Device Farm
- **Verdict: TOO EXPENSIVE for regular CI**
- Pricing: $0.17/device-minute = $10.20/hour
- A 15-minute test run = $2.55 per run
- 66 runs/month = $168/month (over budget)
- Unlimited plan: $250/month per device slot
- **Escalation path**: use for release branch validation only

### Self-Hosted Mac Mini M4
- **Verdict: PREMATURE**
- Hardware cost: $599 (Mac Mini M4) + electricity
- MacStadium rental: ~$199/month
- Macly.io: from $14.99/month
- Benefit: native ARM emulator, no ABI translation, fastest possible
- Drawback: maintenance burden, single point of failure
- GitHub now charges $0.002/min for self-hosted runners (March 2026)
- **Escalation path**: if we run >200 CI minutes/day, self-hosted becomes cheaper

### Codemagic
- **Verdict: VIABLE ALTERNATIVE**
- Has first-class Patrol integration with documentation
- Mac Mini M2 instances available
- Can build APKs and send to Firebase Test Lab
- Pricing: free tier has 500 build minutes/month
- **Consider**: if GitHub Actions emulator is too slow or flaky

## Cost Breakdown

### Current Architecture (GitHub Actions)

| Component | Per-Run Cost | Monthly (66 runs) |
|-----------|-------------|-------------------|
| Build job (4-core, ~25 min) | $0.30 | $19.80 |
| Test job (2-core, ~15 min) | $0.09 | $5.94 |
| Artifact storage | ~$0.01 | $0.66 |
| **Total** | **$0.40** | **$26.40** |

With cache misses, retries, and workflow_dispatch runs: **~$40-60/month**

### If Escalation Needed

| Scenario | Additional Monthly Cost |
|----------|----------------------|
| emulator.wtf (10 hrs/month) | +$20 |
| AWS Device Farm (main only, 22 runs) | +$56 |
| Self-hosted Mac Mini M4 | +$15-199 (rent) or $599 one-time |

## Runner Pricing Reference (January 2026)

| Runner | Per-Minute | Notes |
|--------|-----------|-------|
| Linux 2-core (standard) | $0.006 | Has KVM, Docker |
| Linux 4-core (larger) | $0.012 | Requires Team/Enterprise plan |
| Linux 8-core (larger) | $0.022 | |
| Linux 2-core ARM64 | $0.005 | No Android emulator available |
| macOS 3-core (M1) | $0.062 | 10x more expensive than Linux |
| macOS 12-core (larger) | $0.077 | |
| Self-hosted (any) | $0.002 | Platform charge since March 2026 |

## Patrol CI Integration Notes

From [patrol.leancode.co/ci/platforms](https://patrol.leancode.co/ci/platforms):

> "Running an Android emulator on the default GitHub Actions runner is a bad
> idea. It is slow to start and unstable (apps crash randomly) and very slow."

This was written before KVM was available on standard ubuntu-latest runners
(April 2024). With KVM, the emulator is significantly more stable and 2-3x
faster. The situation has improved substantially.

**Key Patrol CI commands:**
```bash
# Build APKs (on build runner)
patrol build android --target patrol_test/app_launch_test.dart --debug

# Run tests (on emulator)
adb shell am instrument -w \
  -e clearPackageData true \
  com.bullbitcoin.mobile.test/pl.leancode.patrol.PatrolJUnitRunner
```

## Future Improvements

1. **Test sharding**: Split tests across multiple emulator instances for parallelism
2. **Flaky test retry**: Add `--num-flaky-test-attempts` if using emulator.wtf
3. **Visual regression**: Capture screenshots and diff with golden files
4. **Mainnet dust tests**: Run on real device farm (AWS) with network access
5. **iOS E2E**: Add Xcode Cloud or macOS runner job when iOS is unblocked
