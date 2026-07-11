import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bull_sdk/bwk.dart';

/// Result of testing one backend URL: ok, or a human-readable error.
enum SpConnTest { untested, testing, ok, failed }

/// Which backend a URL points at. Lets the connection test and the form logic
/// share one implementation instead of a blindbit/electrum pair.
enum BackendKind { blindbit, electrum }

/// Validates a blindbit / electrum URL by actually connecting (standalone, no
/// live SP session). Returns null on success or an error message. The bwk free
/// functions are injectable so the usecase can be unit-tested.
class TestSpBackendUsecase {
  final Future<int> Function({required String url}) _testBlindbit;
  final Future<void> Function({required String url}) _testElectrum;

  TestSpBackendUsecase({
    Future<int> Function({required String url})? testBlindbit,
    Future<void> Function({required String url})? testElectrum,
  }) : _testBlindbit = testBlindbit ?? testBlindbitUrl,
       _testElectrum = testElectrum ?? testElectrumUrl;

  /// Returns null when the URL connects, or [SpBackendUnreachable] carrying the
  /// raw reason as `logMessage` (never shown to the user) otherwise.
  Future<SpFailure?> test(BackendKind kind, String url) async {
    try {
      switch (kind) {
        case BackendKind.blindbit:
          await _testBlindbit(url: url);
        case BackendKind.electrum:
          await _testElectrum(url: url);
      }
      return null;
    } catch (e) {
      return SpBackendUnreachable('SP backend test failed ($url): $e');
    }
  }
}
