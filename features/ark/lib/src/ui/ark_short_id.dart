/// A long id or address on one line: its start and end, as the app's
/// transaction details show them. The full value stays copyable.
String arkShortId(String value) => value.length <= 24
    ? value
    : '${value.substring(0, 12)}…${value.substring(value.length - 8)}';
