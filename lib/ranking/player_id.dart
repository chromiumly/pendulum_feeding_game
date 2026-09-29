/// Player IDs come from the QR codes handed to the guests:
/// `https://…/pendulum_feeding_game/?id=<16 lowercase letters or digits>`.
///
/// The ID is a secret: anyone who knows it can record games as that player.
final _playerIdPattern = RegExp(r'^[a-z0-9]{16}$');

bool isValidPlayerId(String id) => _playerIdPattern.hasMatch(id);

/// The player ID in [uri]'s `id` query parameter, or null if there is none
/// or it is malformed.
String? playerIdFromUri(Uri uri) {
  final id = uri.queryParameters['id']?.trim().toLowerCase();
  if (id == null || !isValidPlayerId(id)) return null;
  return id;
}
