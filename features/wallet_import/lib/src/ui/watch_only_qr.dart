import 'dart:convert';

import 'package:bull_ui/bull_ui.dart' show BullBottomSheet, BullTypographyX;
import 'package:material_ui/material_ui.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:satoshifier/satoshifier.dart' show Descriptor;
import 'package:signers/signers.dart';
import 'package:wallet_import/src/domain/import_failure.dart';
import 'package:wallet_import/src/domain/watch_only_input.dart';
import 'package:wallet_import/src/presentation/import_l10n.dart';

@useResult
Future<Result<WatchOnlyInput?, ImportFailure>> readWatchOnlyQr(
  BuildContext context,
  String payload, {
  SignerDevice? device,
}) async {
  final String? input;
  if (device == SignerDevice.krux) {
    try {
      input = Descriptor.parse(payload).external;
    } catch (error) {
      if (error is Error) rethrow;
      return const Err(InvalidWatchOnlyInputFailure());
    }
  } else if (device == SignerDevice.passport ||
      device == SignerDevice.keystone) {
    switch (await _chooseDerivation(context, payload)) {
      case Ok(:final value):
        input = value;
      case Err(:final failure):
        return Err(failure);
    }
  } else {
    input = payload;
  }
  if (input == null || !context.mounted) return const Ok(null);
  return WatchOnlyInput.parse(input, signerDevice: device);
}

Future<Result<String?, ImportFailure>> _chooseDerivation(
  BuildContext context,
  String data,
) async {
  final Object? parsed;
  try {
    parsed = jsonDecode(data);
  } on FormatException {
    return const Err(InvalidWatchOnlyInputFailure());
  }
  if (parsed is! Map<String, dynamic>) {
    return const Err(InvalidWatchOnlyInputFailure());
  }

  final options = [
    for (final (key, label) in const [
      ('bip84', 'Segwit (BIP84)'),
      ('bip49', 'Nested Segwit (BIP49)'),
      ('bip44', 'Legacy (BIP44)'),
    ])
      if (parsed[key] case final String descriptor)
        (label: label, descriptor: descriptor),
  ];
  if (options.isEmpty) return const Err(InvalidWatchOnlyInputFailure());
  if (options.length == 1) return Ok(options.single.descriptor);

  final choice = await BullBottomSheet.show<String>(
    context: context,
    child: SafeArea(
      child: Column(
        mainAxisSize: .min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              context.loc.importWatchOnlySelectDerivation,
              style: context.bullType.body.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          for (final option in options)
            ListTile(
              title: Text(option.label),
              onTap: () => Navigator.of(context).pop(option.descriptor),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  return Ok(choice);
}
