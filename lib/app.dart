import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'router/app_router.dart';

class TrvlrApp extends ConsumerWidget {
  const TrvlrApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Trvlr',
      theme: buildAppTheme(),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
