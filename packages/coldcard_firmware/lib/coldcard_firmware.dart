/// Pure-Dart library to discover, download and verify Coldcard firmware against Coinkite's PGP-signed release manifest.
///
/// Entry point: [ColdcardFirmwareClient]. Everything security-relevant is deliberately NOT exported: the trust anchor, endpoints and verifier construction are fixed at compile time, and `DownloadedFirmware`/`VerifiedFirmware` can only be produced by the client itself.
library;

export 'src/firmware/client.dart'
    show ColdcardFirmwareClient, DownloadedFirmware, VerifiedFirmware;
export 'src/firmware/failures.dart'
    show
        ColdcardFirmwareException,
        DiscoveryParseException,
        FirmwareHashMismatchException,
        FirmwareNetworkException,
        FirmwareTooLargeException,
        ManifestSignatureException,
        ManifestWrongKeyException,
        ReleaseNotInManifestException,
        ResponseTooLargeException;
export 'src/firmware/model.dart' show ColdcardModel;
export 'src/firmware/release.dart' show FirmwareRelease, FirmwareVersion;
export 'src/firmware/trusted_key.dart'
    show trustedSignerFingerprintHex, trustedSignerIdentity;
