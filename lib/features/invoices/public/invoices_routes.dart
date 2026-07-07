import 'package:bb_mobile/features/invoices/presentation/invoice_create_cubit.dart';
import 'package:bb_mobile/features/invoices/presentation/invoice_detail_cubit.dart';
import 'package:bb_mobile/features/invoices/presentation/invoices_list_cubit.dart';
import 'package:bb_mobile/features/invoices/public/invoices_facade.dart';
import 'package:bb_mobile/features/invoices/ui/screens/invoice_create_screen.dart';
import 'package:bb_mobile/features/invoices/ui/screens/invoice_detail_screen.dart';
import 'package:bb_mobile/features/invoices/ui/screens/invoices_list_screen.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum InvoicesRoute {
  list('invoices'),
  create('create'),
  detail('detail/:id');

  final String path;

  const InvoicesRoute(this.path);
}

class InvoicesRoutes {
  const InvoicesRoutes._();

  static final route = GoRoute(
    name: InvoicesRoute.list.name,
    path: InvoicesRoute.list.path,
    builder: (context, state) => BlocProvider(
      create: (_) => locator<InvoicesListCubit>()..load(),
      child: const InvoicesListScreen(),
    ),
    routes: [
      GoRoute(
        name: InvoicesRoute.create.name,
        path: InvoicesRoute.create.path,
        builder: (context, state) => BlocProvider(
          create: (_) => locator<InvoiceCreateCubit>()..loadCurrencies(),
          child: const InvoiceCreateScreen(),
        ),
      ),
      GoRoute(
        name: InvoicesRoute.detail.name,
        path: InvoicesRoute.detail.path,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final invoice = state.extra is Invoice ? state.extra as Invoice : null;
          return BlocProvider(
            create: (_) => InvoiceDetailCubit(
              facade: locator<InvoicesFacade>(),
              invoiceId: InvoiceId(id),
              invoice: invoice,
            )..load(),
            child: const InvoiceDetailScreen(),
          );
        },
      ),
    ],
  );
}
