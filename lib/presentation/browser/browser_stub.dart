/// Off the web: no full screen and no files.
library;

/// Asks the browser to show the page full screen, unless it already does.
/// Call it while handling a click or key press, or the browser refuses.
void requestFullscreen() {}

/// Lets the user choose a text file, and returns its contents, or null if
/// none was chosen.
Future<String?> pickTextFile() async => null;

/// The contents of every file dropped onto the page.
Stream<String> droppedTextFiles() => const Stream.empty();
