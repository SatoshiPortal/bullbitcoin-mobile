import 'package:bb_mobile/features/receive/presentation/screens/receive_amount_screen.dart';
import 'package:bb_mobile/features/receive/presentation/screens/receive_success_screen.dart';
import 'package:go_router/go_router.dart';

enum ReceiveSubroute {
  amount('amount'),
  //invoice('invoice'),
  success('success');

  final String path;

  const ReceiveSubroute(this.path);
}

class ReceiveRouter {
  static final routes = [
    GoRoute(
      name: ReceiveSubroute.amount.name,
      path: ReceiveSubroute.amount.path,
      builder: (context, state) => const ReceiveAmountScreen(),
    ),
    GoRoute(
      name: ReceiveSubroute.success.name,
      path: ReceiveSubroute.success.path,
      builder: (context, state) => const ReceiveSuccessScreen(),
    ),
  ];
}
