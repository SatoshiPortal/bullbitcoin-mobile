import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';

class GetSecretFromFingerprintUsecase {
  final Secrets _secrets;

  GetSecretFromFingerprintUsecase({required this._secrets});

  /// Finds the wallet's secret handle.
  ///
  /// A handle, not the words: the mnemonic is read inside `MnemonicView` and
  /// `MnemonicChallenge` at the moment it is drawn, and there is no longer an
  /// app path that could hold it. This usecase is what makes that possible —
  /// it carries a description and a reference, both safe to keep.
  Future<Secret> execute(String fingerprint) async =>
      switch (await _secrets.fetch(Fingerprint(fingerprint))) {
        Ok(:final value) => value,
        Err(:final failure) => throw Exception('${failure.runtimeType}'),
      };
}
