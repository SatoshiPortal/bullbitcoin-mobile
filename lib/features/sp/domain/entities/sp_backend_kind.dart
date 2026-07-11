/// Which backend a URL points at. Lets the connection test and the form logic
/// share one implementation instead of a blindbit/electrum pair.
enum SpBackendKind { blindbit, electrum }
