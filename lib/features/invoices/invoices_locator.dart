import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_address_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/invoices/application/ports/invoices_identity_port.dart';
import 'package:bb_mobile/features/invoices/application/ports/invoices_pay_service_port.dart';
import 'package:bb_mobile/features/invoices/application/usecases/cancel_invoice_usecase.dart';
import 'package:bb_mobile/features/invoices/application/usecases/create_invoice_usecase.dart';
import 'package:bb_mobile/features/invoices/application/usecases/get_invoice_usecase.dart';
import 'package:bb_mobile/features/invoices/application/usecases/list_invoices_usecase.dart';
import 'package:bb_mobile/features/invoices/data/datasources/invoices_identity_datasource.dart';
import 'package:bb_mobile/features/invoices/data/datasources/invoices_pay_service_datasource.dart';
import 'package:bb_mobile/features/invoices/public/invoices_facade.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:get_it/get_it.dart';

class InvoicesLocator {
  static void setup(GetIt locator) {
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
    locator.registerFactory<GetInvoiceUsecase>(
      () => GetInvoiceUsecase(payService: locator<InvoicesPayServicePort>()),
    );
    locator.registerFactory<InvoicesFacade>(
      () => InvoicesFacade(
        create: locator<CreateInvoiceUsecase>(),
        cancel: locator<CancelInvoiceUsecase>(),
        list: locator<ListInvoicesUsecase>(),
        getStatus: locator<GetInvoiceUsecase>(),
        bullnym: locator<BullnymFacade>(),
      ),
    );
  }
}
