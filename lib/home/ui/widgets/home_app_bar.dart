import 'package:flutter/material.dart';

class HomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  const HomeAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

// import 'package:bb_mobile/_utils/build_context_x.dart';
// import 'package:bb_mobile/router.dart';
// import 'package:flutter/material.dart';
// import 'package:go_router/go_router.dart';

// class HomeAppBar extends StatelessWidget implements PreferredSizeWidget {
//   const HomeAppBar({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return AppBar(
//       centerTitle: false,
//       title: Row(
//         crossAxisAlignment: CrossAxisAlignment.end,
//         spacing: 16,
//         children: [
//           Image.asset(
//             'assets/bb-logo-small.png',
//             height: 40,
//             width: 40,
//           ),
//           Column(
//             mainAxisSize: MainAxisSize.min,
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Row(
//                 crossAxisAlignment: CrossAxisAlignment.end,
//                 mainAxisSize: MainAxisSize.min,
//                 spacing: 8,
//                 children: [
//                   Image.asset(
//                     'assets/textlogo.png',
//                     height: 20,
//                     width: 108,
//                   ),
//                   Text('BETA', style: context.theme.textTheme.bodySmall),
//                 ],
//               ),
//               Text(
//                 '137914.5 CAD',
//                 style: context.theme.textTheme.bodySmall,
//               ),
//             ],
//           ),
//         ],
//       ),
//       actions: [
//         IconButton(
//           onPressed: () => context.pushNamed(AppRoute.settings.name),
//           icon: const Icon(Icons.settings),
//         ),
//         const IconButton(onPressed: null, icon: Icon(Icons.person)),
//       ],
//     );
//   }

//   @override
//   Size get preferredSize => const Size.fromHeight(kToolbarHeight);
// }
