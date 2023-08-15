import 'package:editor/editor/controller.dart';
import 'package:flutter/material.dart';

class IndentationIntent extends Intent {
  const IndentationIntent();
}

class NewlineIntent extends Intent {
  const NewlineIntent();
}

class PairInsertionIntent extends Intent {
  final CharacterPair pair;

  const PairInsertionIntent(this.pair);
}
