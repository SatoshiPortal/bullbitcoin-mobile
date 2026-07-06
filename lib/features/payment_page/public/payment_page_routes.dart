import 'package:bb_mobile/features/payment_page/presentation/payment_page_cubit.dart';
import 'package:bb_mobile/features/payment_page/ui/screens/payment_page_editor_screen.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum PaymentPageRoute {
  paymentPageSettings('payment-page');

  final String path;

  const PaymentPageRoute(this.path);
}

class PaymentPageRoutes {
  const PaymentPageRoutes._();

  static final route = GoRoute(
    name: PaymentPageRoute.paymentPageSettings.name,
    path: PaymentPageRoute.paymentPageSettings.path,
    builder: (context, state) => BlocProvider(
      create: (_) => locator<PaymentPageCubit>(),
      child: const PaymentPageEditorScreen(),
    ),
  );
}
