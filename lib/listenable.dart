import 'package:flutter/material.dart';

class ListenableWatcher extends StatelessWidget {
  final Listenable listenable;
  final Widget child;

  const ListenableWatcher({
    required this.listenable,
    required this.child,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: listenable,
      builder: (context, _) => child,
    );
  }
}
