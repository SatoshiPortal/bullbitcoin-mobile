import 'package:address_view/address_view.dart';
import 'package:address_view/routes.dart';
import 'package:labels/labels.dart';
import 'package:secrets/storage.dart' show SecretsInventory;
import 'package:sync/write.dart' show WalletNativeRuntime;
import 'package:get_it/get_it.dart';

void mountAddressView(GetIt locator) {
  locator.registerLazySingleton<AddressViewFeature>(() {
    final native = locator<WalletNativeRuntime>();
    return AddressViewFeature.mount(
      labels: locator<Labels>(),
      inventory: locator<SecretsInventory>(),
      native: native,
      loadWallet: native.loadWallet,
      revisions: native.changes,
    );
  });
  locator.registerLazySingleton<AddressView>(
    () => locator<AddressViewFeature>().addresses,
  );
}
