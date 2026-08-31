import 'package:bull_swap/src/domain/swap_provider_kind.dart';
import 'package:meta/meta.dart';

@immutable
class SwapProviderConfig {
  final String id;
  final SwapProviderKind kind;
  final String name;
  final String? baseUrl;
  final bool isBuiltIn;

  const SwapProviderConfig({
    required this.id,
    required this.kind,
    required this.name,
    this.baseUrl,
    this.isBuiltIn = false,
  });

  // A Boltz provider is useless without a server URL; Bull's URL is fixed in the
  // built-in config, so a missing one there is a programming error, not input.
  bool get isConfigured => kind == SwapProviderKind.bull || baseUrl != null;

  SwapProviderConfig copyWith({String? name, String? baseUrl}) =>
      SwapProviderConfig(
        id: id,
        kind: kind,
        name: name ?? this.name,
        baseUrl: baseUrl ?? this.baseUrl,
        isBuiltIn: isBuiltIn,
      );

  @override
  bool operator ==(Object other) =>
      other is SwapProviderConfig &&
      other.id == id &&
      other.kind == kind &&
      other.name == name &&
      other.baseUrl == baseUrl &&
      other.isBuiltIn == isBuiltIn;

  @override
  int get hashCode => Object.hash(id, kind, name, baseUrl, isBuiltIn);
}
