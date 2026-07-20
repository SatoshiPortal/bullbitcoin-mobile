/// Signed Bullnym fiat-settlement action names and payload-field builders.
///
/// These ride the same `bullpay-la-v2` signer as the other Bullnym actions and
/// always sign an EMPTY nym slot (fiat settlement is npub-wide, not per-nym).
/// Renaming an action or reordering a payload is a breaking protocol change.
///
/// Per the validated MVP contract there is NO terms field: the `set` signature
/// covers `[version, product, fiat_percentage, currency_or_empty,
/// api_key_or_empty]`. Absent optionals are signed as the empty string so the
/// NUL-separator count is invariant.
const String bullpayActionFiatSettlementSet = 'fiat-settlement-set';
const String bullpayActionFiatSettlementGet = 'fiat-settlement-get';

/// The signed `fiat-settlement-set` payload, in the server's fixed order.
///
/// [fiatPercentage] is decimal (`u8::to_string`). When it is 0 (Bitcoin-only /
/// disable) the currency and api_key slots MUST be empty strings — the caller
/// is responsible for passing empty values in that case.
List<String> buildFiatSettlementSetPayloadFields({
  required String product,
  required int fiatPercentage,
  required String currencyOrEmpty,
  required String apiKeyOrEmpty,
}) {
  return [
    '1',
    product,
    fiatPercentage.toString(),
    currencyOrEmpty,
    apiKeyOrEmpty,
  ];
}

/// The signed `fiat-settlement-get` payload: `[version]` only.
List<String> buildFiatSettlementGetPayloadFields() => ['1'];
