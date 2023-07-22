import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef RefWidgetBuilder = Widget Function(BuildContext context, WidgetRef ref);

class RefWidget extends ConsumerWidget {
  final RefWidgetBuilder builder;

  const RefWidget({
    required this.builder,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return builder(context, ref);
  }
}
