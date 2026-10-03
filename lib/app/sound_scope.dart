/// Gives the screens the app's sound controller.
library;

import 'package:flutter/widgets.dart';

import '../audio/sound_controller.dart';

/// Holds the app's [SoundController] for everything below it, so that every
/// screen shares one switch and one music. The controller is null for an app
/// without sound, in which case no screen shows a sound button.
class SoundScope extends InheritedWidget {
  const SoundScope({super.key, required this.controller, required super.child});

  /// The app's sound, or null for none.
  final SoundController? controller;

  /// Returns the sound controller above [context], or null if the app has
  /// none. Does not rebuild when sound is switched; listen to the controller
  /// for that.
  static SoundController? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<SoundScope>()?.controller;

  @override
  bool updateShouldNotify(SoundScope oldWidget) =>
      controller != oldWidget.controller;
}
