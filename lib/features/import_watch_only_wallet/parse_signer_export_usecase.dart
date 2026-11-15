import 'package:bb_mobile/features/import_watch_only_wallet/domain/import_watch_only_failure.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/domain/signer_export.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/watch_only_wallet_entity.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart' show Err, Ok, Result;
import 'package:satoshifier/satoshifier.dart' as satoshifier;

final class SignerExportOption {
  final String derivation;
  final WatchOnlyWalletEntity wallet;

  const SignerExportOption({required this.derivation, required this.wallet});
}

typedef WatchOnlyParser = Future<WatchOnlyWalletEntity> Function(String input);
typedef ExternalDescriptorReader = String Function(String input);

String satoshifierExternalDescriptor(String input) =>
    satoshifier.Descriptor.parse(input).external;

class ParseSignerExportUsecase {
  final WatchOnlyParser _parse;
  final ExternalDescriptorReader _externalDescriptor;

  const ParseSignerExportUsecase({
    this._parse = WatchOnlyWalletEntity.parse,
    this._externalDescriptor = satoshifierExternalDescriptor,
  });

  @useResult
  Future<Result<List<SignerExportOption>, ImportWatchOnlyFailure>> execute(
    String input,
  ) async {
    final options = <SignerExportOption>[];
    final descriptors = SignerExport.descriptors(input);
    for (final (:derivation, :descriptor) in descriptors) {
      try {
        options.add(
          SignerExportOption(
            derivation: derivation,
            wallet: await _parse(descriptor),
          ),
        );
      } catch (e) {
        log.warning('Signer export: descriptor rejected (${e.runtimeType})');
      }
    }
    if (options.isNotEmpty) return Ok(options);
    if (descriptors.isNotEmpty) return const Err(InvalidFormatFailure());

    try {
      final wallet = await _parse(_externalDescriptor(input));
      return Ok([
        SignerExportOption(derivation: wallet.scriptType.name, wallet: wallet),
      ]);
    } catch (e) {
      log.warning('Signer export: input rejected (${e.runtimeType})');
      return const Err(InvalidFormatFailure());
    }
  }
}
