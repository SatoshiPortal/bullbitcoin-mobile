/// Test support: the generated bridge, for `BullSdk.initMock` and the
/// `BullSdkApi` mocks. Production code imports `rust_bindings.dart` and the
/// per-library entry points; the custody gate rejects `initMock` there.
library;

export 'src/rust/frb_generated.dart';
