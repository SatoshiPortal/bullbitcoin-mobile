import 'package:bb_mobile/features/template/ui/empty_page.dart';
import 'package:bb_mobile/features/template/ui/template_page.dart';
import 'package:go_router/go_router.dart';

enum TemplateRoute {
  templateFeatureFlow('/template-feature-flow'),
  emptyPage('/empty-page');

  final String path;

  const TemplateRoute(this.path);
}

class TemplateFeatureRouter {
  static final route = GoRoute(
    name: TemplateRoute.templateFeatureFlow.name,
    path: TemplateRoute.templateFeatureFlow.path,
    builder: (context, state) => const TemplatePage(),
    routes: [
      // sub routes
      GoRoute(
        name: TemplateRoute.emptyPage.name,
        path: TemplateRoute.emptyPage.path,
        builder: (context, state) {
          final someData = state.extra! as String;
          return EmptyPage(someData: someData);
        },
      ),
    ],
  );
}
