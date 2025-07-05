import 'package:bb_mobile/features/template/ui/template_flow.dart';
import 'package:go_router/go_router.dart';

enum TemplateRoute {
  templateFeatureFlow('/template-feature-flow');

  final String path;

  const TemplateRoute(this.path);
}

class TemplateFeatureRouter {
  static final route = GoRoute(
    name: TemplateRoute.templateFeatureFlow.name,
    path: TemplateRoute.templateFeatureFlow.path,
    builder: (context, state) {
      final Map<String, dynamic>? extra = state.extra as Map<String, dynamic>?;
      return TemplateFlow(
        initialData: extra?['initialData'] as String?,
        fromScreen: extra?['fromScreen'] as String?,
      );
    },
  );
}
