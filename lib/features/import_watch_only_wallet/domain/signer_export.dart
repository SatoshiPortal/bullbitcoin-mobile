import 'dart:convert';

abstract final class SignerExport {
  static const derivations = ['bip84', 'bip49', 'bip44'];

  static List<({String derivation, String descriptor})> descriptors(
    String data,
  ) {
    final Object? parsed;
    try {
      parsed = json.decode(data);
    } on FormatException {
      return const [];
    }
    if (parsed is! Map<String, dynamic>) return const [];
    return [
      for (final derivation in derivations)
        if (parsed[derivation] case final String descriptor)
          (derivation: derivation, descriptor: descriptor),
    ];
  }
}
