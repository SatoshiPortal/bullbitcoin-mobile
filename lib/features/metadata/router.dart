// import 'package:bb_mobile/features/bip85_entropy/bip85_home_page.dart';
// import 'package:bb_mobile/features/bip85_entropy/presentation/cubit.dart';
// import 'package:bb_mobile/features/metadata/home_page.dart';
// import 'package:bb_mobile/locator.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';
// import 'package:go_router/go_router.dart';

// enum MetadataRoute {
//   home('/metadata-home'),
//   export('/metadata-export');

//   final String path;

//   const MetadataRoute(this.path);
// }

// class MetadataRouter {
//   static final route = ShellRoute(
//     builder:
//         (context, state, child) => BlocProvider(
//           create: (_) => locator<Bip85EntropyCubit>(),
//           child: child,
//         ),
//     routes: [
//       GoRoute(
//         name: MetadataRoute.home.name,
//         path: MetadataRoute.home.path,
//         builder: (context, state) => const MetadataHomePage(),
//         routes: const [],
//       ),
//       // GoRoute(
//       //   name: MetadataRoute.export.name,
//       //   path: MetadataRoute.export.path,
//       //   builder: (context, state) => const EmptyPage(),
//       //   routes: const [],
//       // ),
//     ],
//   );
// }
