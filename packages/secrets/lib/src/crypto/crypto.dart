/// What the package computes, and with which library.
///
/// The only module that imports the FFI bindings — bdk, lwk, boltz — and
/// recoverbull. Everything here is a pure function of key material; a
/// signer or deriver holds no state, no network client and nothing on
/// disk beyond lwk's scratch directory. The exceptions listed are the
/// module's contract with the error boundary in `public/`.
library;

export 'backups/backups.dart';
export 'derivers/derivers.dart';
export 'exceptions.dart';
export 'generator.dart' show Generator;
export 'signers/signers.dart';
