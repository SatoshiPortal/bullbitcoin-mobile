import 'package:bull_ui/bull_ui.dart';
import 'package:go_router/go_router.dart';

/// Shared by the standalone and wallet-hosted Ark routers.
class ArkReviewPage extends CustomTransitionPage<Object?> {
  ArkReviewPage({
    required super.key,
    required super.child,
    required BuildContext context,
  }) : super(
         opaque: false,
         barrierDismissible: false,
         barrierColor: context.bull.surface.withAlpha(100),
         transitionsBuilder: (context, animation, secondaryAnimation, child) =>
             child,
       );
}
