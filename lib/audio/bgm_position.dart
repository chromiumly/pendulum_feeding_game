/// Where the background music is, after it has played on unheard.
library;

/// Returns where the music would be now had it kept playing while it was
/// silent.
///
/// [positionAtMute] is where it was when it was silenced, [mutedFor] how
/// long ago that was, and [length] the music's whole length. The music
/// loops, so the result wraps round: always from zero up to, but not
/// including, [length].
Duration positionAfterMute({
  required Duration positionAtMute,
  required Duration mutedFor,
  required Duration length,
}) => Duration(
  microseconds:
      (positionAtMute + mutedFor).inMicroseconds % length.inMicroseconds,
);
