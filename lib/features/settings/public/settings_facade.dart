/// Public contract of the settings feature.
///
/// The only surface other features (and this feature's own UI) should import
/// to reach settings capabilities. Internals under `presentation/`, `domain/`
/// and `ui/` are not importable directly.
///
/// For now this exposes the Novlang store-vocabulary helper; grow the export
/// block as more of settings becomes a published contract.
library;

export 'package:bb_mobile/features/settings/public/novlang_x.dart';
