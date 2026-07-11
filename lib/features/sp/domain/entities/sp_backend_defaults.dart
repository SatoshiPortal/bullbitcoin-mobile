import 'package:bb_mobile/features/sp/domain/sp_failure.dart';

/// Backend (blindbit + electrum) default URLs for a network, or the failure
/// that prevented resolving them (regtest infra unreachable, missing default).
class SpBackendDefaults {
  final SpFailure? failure;
  final String blindbitUrl;
  final String electrumUrl;

  const SpBackendDefaults({
    required this.failure,
    required this.blindbitUrl,
    required this.electrumUrl,
  });

  const SpBackendDefaults.ok({
    required String blindbitUrl,
    required String electrumUrl,
  }) : this(failure: null, blindbitUrl: blindbitUrl, electrumUrl: electrumUrl);

  const SpBackendDefaults.failed(SpFailure failure)
    : this(failure: failure, blindbitUrl: '', electrumUrl: '');

  bool get isOk => failure == null;
}
