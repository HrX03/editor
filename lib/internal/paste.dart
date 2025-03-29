import 'package:clipboard_watcher/clipboard_watcher.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final pasteContentsProvider = ChangeNotifierProvider((ref) => PasteListenable());

class PasteListenable extends ChangeNotifier with ClipboardListener {
  bool _pasteAllowed = false;

  PasteListenable() {
    clipboardWatcher.addListener(this);
    clipboardWatcher.start();
  }

  @override
  void dispose() {
    clipboardWatcher.removeListener(this);
    clipboardWatcher.stop();
    super.dispose();
  }

  @override
  Future<void> onClipboardChanged() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final pasteAllowed = data != null;
    if (pasteAllowed != _pasteAllowed) {
      _pasteAllowed = data != null;
      notifyListeners();
    }
  }

  bool get value => _pasteAllowed;
}
