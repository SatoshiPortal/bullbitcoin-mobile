enum SwapProviderKind {
  bull,
  boltz;

  static SwapProviderKind fromName(String value) => switch (value) {
    'bull' => SwapProviderKind.bull,
    'boltz' => SwapProviderKind.boltz,
    _ => throw ArgumentError('Unknown SwapProviderKind: $value'),
  };
}
