/// On the web, through the browser's own APIs.
library;

import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Asks the browser to show the page full screen, unless it already does.
/// Call it while handling a click or key press, or the browser refuses.
void requestFullscreen() {
  if (web.document.fullscreenElement != null) return;
  final page = web.document.documentElement;
  if (page == null) return;
  // Refused, e.g. outside a click: the page just stays as it is.
  unawaited(page.requestFullscreen().toDart.then((_) {}, onError: (_) {}));
}

/// Lets the user choose a text file, and returns its contents, or null if
/// none was chosen.
Future<String?> pickTextFile() {
  final done = Completer<String?>();
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = '.json,application/json';
  void finish(Future<String?> contents) {
    if (!done.isCompleted) done.complete(contents);
  }

  input
    ..addEventListener(
      'change',
      (web.Event _) {
        final file = input.files?.item(0);
        finish(file == null ? Future.value() : _read(file));
      }.toJS,
    )
    ..addEventListener(
      'cancel',
      (web.Event _) {
        finish(Future.value());
      }.toJS,
    )
    ..click();
  return done.future;
}

/// The contents of every file dropped onto the page.
Stream<String> droppedTextFiles() {
  late final StreamController<String> controller;
  // Without this, the browser opens a dropped file in place of the page.
  void onDragOver(web.Event event) => event.preventDefault();
  void onDrop(web.Event event) {
    event.preventDefault();
    final file = (event as web.DragEvent).dataTransfer?.files.item(0);
    if (file != null) {
      _read(file).then(controller.add, onError: controller.addError);
    }
  }

  final dragOver = onDragOver.toJS;
  final drop = onDrop.toJS;
  controller = StreamController<String>(
    onListen: () {
      web.window
        ..addEventListener('dragover', dragOver, true.toJS)
        ..addEventListener('drop', drop, true.toJS);
    },
    onCancel: () {
      web.window
        ..removeEventListener('dragover', dragOver, true.toJS)
        ..removeEventListener('drop', drop, true.toJS);
    },
  );
  return controller.stream;
}

Future<String> _read(web.File file) async => (await file.text().toDart).toDart;
