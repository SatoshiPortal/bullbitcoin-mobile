import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_address_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/bullnym/public/bullnym_config.dart';
import 'package:bb_mobile/features/invoices/application/ports/invoices_identity_port.dart';
import 'package:bb_mobile/features/invoices/application/ports/invoices_pay_service_port.dart';
import 'package:bb_mobile/features/invoices/application/usecases/cancel_invoice_usecase.dart';
import 'package:bb_mobile/features/invoices/application/usecases/create_invoice_usecase.dart';
import 'package:bb_mobile/features/invoices/application/usecases/get_invoice_usecase.dart';
import 'package:bb_mobile/features/invoices/application/usecases/list_invoices_usecase.dart';
import 'package:bb_mobile/features/invoices/application/usecases/list_invoice_fallback_supervision_usecase.dart';
import 'package:bb_mobile/features/invoices/data/private_invoice_cipher_impl.dart';
import 'package:bb_mobile/features/invoices/data/private_invoice_link_repository_impl.dart';
import 'package:bb_mobile/features/invoices/data/datasources/invoices_identity_datasource.dart';
import 'package:bb_mobile/features/invoices/data/datasources/invoices_pay_service_datasource.dart';
import 'package:bb_mobile/features/invoices/domain/private_invoice_cipher.dart';
import 'package:bb_mobile/features/invoices/domain/repositories/private_invoice_link_repository.dart';
import 'package:bb_mobile/features/invoices/domain/usecases/get_private_invoice_link_usecase.dart';
import 'package:bb_mobile/features/invoices/presentation/invoice_create_cubit.dart';
import 'package:bb_mobile/features/invoices/presentation/invoices_list_cubit.dart';
import 'package:bb_mobile/features/invoices/public/invoices_facade.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:get_it/get_it.dart';

class InvoicesLocator {
  static void setup(GetIt locator) {
    locator.registerLazySingleton<PrivateInvoiceCipher>(
      PrivateInvoiceCipherImpl.new,
    );
    locator.registerLazySingleton<PrivateInvoiceLinkRepository>(
      () => PrivateInvoiceLinkRepositoryImpl(
        storage: locator<KeyValueStorageDatasource<String>>(
          instanceName: LocatorInstanceNameConstants.secureStorageDatasource,
        ),
        expectedOrigin: Uri.parse(bullnymDefaultBaseUrl),
      ),
    );
    locator.registerFactory<InvoicesPayServicePort>(
      () => InvoicesPayServiceDatasource(bullnym: locator<BullnymFacade>()),
    );
    locator.registerFactory<InvoicesIdentityPort>(
      () => InvoicesIdentityDatasource(
        getSettings: locator<GetSettingsUsecase>(),
        walletRepository: locator<WalletRepository>(),
        seedRepository: locator<SeedRepository>(),
        nostrIdentity: locator<NostrIdentityFacade>(),
      ),
    );
    locator.registerFactory<CreateInvoiceUsecase>(
      () => CreateInvoiceUsecase(
        identity: locator<InvoicesIdentityPort>(),
        payService: locator<InvoicesPayServicePort>(),
        cipher: locator<PrivateInvoiceCipher>(),
        links: locator<PrivateInvoiceLinkRepository>(),
        walletRepository: locator<WalletRepository>(),
        walletAddressRepository: locator<WalletAddressRepository>(),
        labels: locator<LabelsFacade>(),
        getSettings: locator<GetSettingsUsecase>(),
      ),
    );
    locator.registerFactory<CancelInvoiceUsecase>(
      () => CancelInvoiceUsecase(
        identity: locator<InvoicesIdentityPort>(),
        payService: locator<InvoicesPayServicePort>(),
      ),
    );
    locator.registerFactory<ListInvoicesUsecase>(
      () => ListInvoicesUsecase(
        identity: locator<InvoicesIdentityPort>(),
        payService: locator<InvoicesPayServicePort>(),
      ),
    );
    locator.registerFactory<ListInvoiceFallbackSupervisionUsecase>(
      () => ListInvoiceFallbackSupervisionUsecase(
        identity: locator<InvoicesIdentityPort>(),
        payService: locator<InvoicesPayServicePort>(),
      ),
    );
    locator.registerFactory<GetInvoiceUsecase>(
      () => GetInvoiceUsecase(payService: locator<InvoicesPayServicePort>()),
    );
    locator.registerFactory<GetPrivateInvoiceLinkUsecase>(
      () =>
          GetPrivateInvoiceLinkUsecase(locator<PrivateInvoiceLinkRepository>()),
    );
    locator.registerFactory<InvoicesFacade>(
      () => InvoicesFacade(
        create: locator<CreateInvoiceUsecase>(),
        cancel: locator<CancelInvoiceUsecase>(),
        list: locator<ListInvoicesUsecase>(),
        listFallbackSupervision:
            locator<ListInvoiceFallbackSupervisionUsecase>(),
        getStatus: locator<GetInvoiceUsecase>(),
        getPrivateLink: locator<GetPrivateInvoiceLinkUsecase>(),
        bullnym: locator<BullnymFacade>(),
      ),
    );

    // Presentation cubits. The list/create cubits are param-less factories; the
    // detail cubit takes the invoice id at the route boundary, so it is built
    // there (not registered here).
    locator.registerFactory<InvoicesListCubit>(
      () => InvoicesListCubit(facade: locator<InvoicesFacade>()),
    );
    locator.registerFactory<InvoiceCreateCubit>(
      () => InvoiceCreateCubit(facade: locator<InvoicesFacade>()),
    );
  }
}
