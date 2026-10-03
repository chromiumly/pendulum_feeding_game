/// Player IDs for the ranking: generates them with their QR codes, and
/// registers them in Firestore (players/{id}).
///
///   dart run tool/ranking/player_ids.dart generate [--count 50]
///       Writes tool/ranking/out/players.csv (number, ID, URL) and
///       tool/ranking/out/qr.html (printable QR codes). Refuses to overwrite
///       an existing players.csv, whose IDs may already be handed out.
///
///   dart run tool/ranking/player_ids.dart register [--emulator]
///       Registers every ID in players.csv, using the service account key in
///       .firebase/. Registering an ID again is harmless: it keeps the
///       player's game count. With --emulator it writes to a local
///       Firestore emulator (localhost:8080) instead.
///
///   dart run tool/ranking/player_ids.dart reset [--emulator]
///       Shows how many documents each ranking collection has. Deletes
///       nothing.
///
///   dart run tool/ranking/player_ids.dart reset --confirm `<project ID>`
///       Deletes every play, score, best and player, e.g. after rehearsals,
///       then registers the IDs in players.csv again (with no games). The
///       IDs, and so the QR codes, stay the same.
///
/// tool/ranking/out/ and .firebase/ are git-ignored: IDs are secrets (anyone
/// with an ID can record games as that player) and so is the key. Which ID
/// is whose is kept by the host outside this project.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:qr/qr.dart';

const _gameUrl = 'https://chromiumly.github.io/pendulum_feeding_game/';
const _projectId = 'pendulum-feeding-game';

/// A demo project ID makes the emulator refuse to reach any real project.
const _emulatorProjectId = 'demo-pendulum-feeding-game';
const _idLength = 16;
const _idChars = 'abcdefghijklmnopqrstuvwxyz0123456789';

final _outDir = Directory('tool/ranking/out');
final _csv = File('tool/ranking/out/players.csv');
final _html = File('tool/ranking/out/qr.html');

/// Runs the command named by the first of [args]: generate, register or
/// reset, with its options. Run from the project root.
Future<void> main(List<String> args) async {
  if (!File('pubspec.yaml').existsSync()) {
    _fail('Run from the project root.');
  }
  switch (args.firstOrNull) {
    case 'generate':
      _generate(count: int.parse(_option(args, '--count') ?? '50'));
    case 'register':
      await _register(emulator: args.contains('--emulator'));
    case 'reset':
      await _reset(
        emulator: args.contains('--emulator'),
        confirm: _option(args, '--confirm'),
      );
    default:
      _fail(
        'Usage: dart run tool/ranking/player_ids.dart '
        'generate [--count N] | register [--emulator] | '
        'reset [--emulator] [--confirm <project ID>]',
      );
  }
}

// ---- generate --------------------------------------------------------------

/// Writes [count] new random IDs to players.csv, with a printable page of
/// their QR codes. Refuses if players.csv exists.
void _generate({required int count}) {
  if (_csv.existsSync()) {
    _fail(
      '${_csv.path} exists; its IDs may already be handed out. '
      'Move it away first to make new ones.',
    );
  }
  final random = math.Random.secure();
  final ids = <String>{};
  while (ids.length < count) {
    ids.add(
      String.fromCharCodes([
        for (var i = 0; i < _idLength; i++)
          _idChars.codeUnitAt(random.nextInt(_idChars.length)),
      ]),
    );
  }
  final players = [
    for (final (i, id) in ids.indexed) (number: i + 1, id: id, url: _url(id)),
  ];

  _outDir.createSync(recursive: true);
  _csv.writeAsStringSync(
    [
      'number,id,url',
      for (final p in players) '${p.number},${p.id},${p.url}',
    ].join('\n'),
  );
  _html.writeAsStringSync(_qrPage(players));
  stdout.writeln(
    'Wrote ${players.length} IDs to ${_csv.path} and ${_html.path}',
  );
}

/// Returns the game URL that plays as [id], encoded in its QR code.
String _url(String id) => '$_gameUrl?id=$id';

/// Returns a printable HTML page with a numbered QR code card per player.
String _qrPage(List<({int number, String id, String url})> players) {
  final cards = [
    for (final p in players)
      '''
<div class="card">
  ${_qrSvg(p.url)}
  <div class="number">No.${p.number.toString().padLeft(2, '0')}</div>
</div>''',
  ].join('\n');
  return '''
<!doctype html>
<html lang="ja">
<head>
<meta charset="utf-8">
<title>花嫁もぐもぐチャレンジ QR</title>
<style>
  body { font-family: sans-serif; margin: 16px; }
  .grid { display: flex; flex-wrap: wrap; gap: 16px; }
  .card { width: 45mm; text-align: center; break-inside: avoid;
          border: 1px dashed #bbb; padding: 4mm; }
  .card svg { width: 100%; height: auto; }
  .number { margin-top: 2mm; font-size: 14px; }
</style>
</head>
<body>
<p>花嫁もぐもぐチャレンジ：参加者ごとのQRコード（ID入り。ほかの人に見せないでください）</p>
<div class="grid">
$cards
</div>
</body>
</html>
''';
}

/// Returns a QR code of [data] as SVG, with a 4-module quiet zone.
String _qrSvg(String data) {
  final image = QrImage(
    QrCode(
      payload: QrPayload.fromString(data),
      errorCorrectLevel: QrErrorCorrectLevel.medium,
    ),
  );
  final size = image.moduleCount + 8;
  final path = StringBuffer();
  for (var row = 0; row < image.moduleCount; row++) {
    for (var col = 0; col < image.moduleCount; col++) {
      if (image.isDark(row, col)) path.write('M${col + 4} ${row + 4}h1v1h-1z');
    }
  }
  return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 $size $size" '
      'shape-rendering="crispEdges"><rect width="$size" height="$size" '
      'fill="#fff"/><path d="$path" fill="#000"/></svg>';
}

// ---- register --------------------------------------------------------------

/// Registers every ID in players.csv, in the emulator if [emulator].
Future<void> _register({required bool emulator}) async {
  final ids = _readIds();
  final firestore = await _Firestore.connect(emulator: emulator);
  try {
    await firestore.register(ids);
  } finally {
    firestore.close();
  }
  stdout.writeln('Registered ${ids.length} IDs in ${firestore.label}.');
}

/// Returns the IDs in players.csv, in order. Exits with an error if the
/// file is missing or an ID is malformed.
List<String> _readIds() {
  if (!_csv.existsSync()) _fail('${_csv.path} not found; run generate first.');
  final ids = [
    for (final line in _csv.readAsLinesSync().skip(1))
      if (line.trim().isNotEmpty) line.split(',')[1],
  ];
  if (ids.any((id) => !RegExp('^[a-z0-9]{$_idLength}\$').hasMatch(id))) {
    _fail('${_csv.path} has a malformed ID.');
  }
  return ids;
}

// ---- reset -----------------------------------------------------------------

/// Everything the game writes, see firestore.rules.
const _rankingCollections = ['plays', 'scores', 'bests', 'players'];

/// Shows how many documents each ranking collection has. Only when
/// [confirm] is the project ID, also deletes them all and registers the IDs
/// again. In the emulator if [emulator].
Future<void> _reset({required bool emulator, String? confirm}) async {
  final ids = _readIds();
  final firestore = await _Firestore.connect(emulator: emulator);
  try {
    final names = {
      for (final collection in _rankingCollections)
        collection: await firestore.documentNames(collection),
    };
    for (final MapEntry(:key, :value) in names.entries) {
      stdout.writeln('${key.padRight(8)} ${value.length} documents');
    }
    if (confirm != firestore.projectId) {
      stdout.writeln(
        'Nothing deleted. To delete all of them in ${firestore.label} and '
        'register the ${ids.length} IDs again, add '
        '--confirm ${firestore.projectId}.',
      );
      return;
    }
    final all = names.values.expand((n) => n).toList();
    await firestore.delete(all);
    stdout.writeln('Deleted ${all.length} documents in ${firestore.label}.');
    await firestore.register(ids);
    stdout.writeln('Registered ${ids.length} IDs in ${firestore.label}.');
  } finally {
    firestore.close();
  }
}

// ---- Firestore REST API ----------------------------------------------------

/// Admin access to the Firestore REST API: with the service account key in
/// .firebase/, or to the local emulator.
class _Firestore {
  _Firestore._(this._client, this._base, this.projectId, this.label);

  /// Connects to the emulator if [emulator], or to the real project with
  /// the key in .firebase/; exits with an error without exactly one key.
  static Future<_Firestore> connect({required bool emulator}) async {
    if (emulator) {
      return _Firestore._(
        _EmulatorClient(),
        'http://localhost:8080/v1',
        _emulatorProjectId,
        '$_emulatorProjectId (emulator)',
      );
    }
    final keys = Directory('.firebase')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList();
    if (keys.length != 1) {
      _fail('Put exactly one service account key (.json) in .firebase/.');
    }
    final credentials = ServiceAccountCredentials.fromJson(
      jsonDecode(keys.single.readAsStringSync()),
    );
    final client = await clientViaServiceAccount(credentials, [
      'https://www.googleapis.com/auth/datastore',
    ]);
    return _Firestore._(
      client,
      'https://firestore.googleapis.com/v1',
      _projectId,
      _projectId,
    );
  }

  final http.Client _client;
  final String _base;
  final String projectId;

  /// For messages: the project, and whether it is the emulator.
  final String label;

  String get _database => 'projects/$projectId/databases/(default)';

  /// Closes the connection.
  void close() => _client.close();

  /// Creates every player in [ids] that is missing. The empty mask leaves
  /// the fields of a registered player (gamesPlayed) as they are.
  Future<void> register(List<String> ids) => _commit([
    for (final id in ids)
      {
        'update': {
          'name': '$_database/documents/players/$id',
          'fields': <String, Object>{},
        },
        'updateMask': {'fieldPaths': <String>[]},
      },
  ]);

  /// Returns the full names of all documents in [collection], page by page.
  Future<List<String>> documentNames(String collection) async {
    final names = <String>[];
    String? pageToken;
    do {
      final uri = Uri.parse('$_base/$_database/documents/$collection').replace(
        queryParameters: {
          'pageSize': '300',
          // Names only, without the fields.
          'mask.fieldPaths': '__name__',
          'pageToken': ?pageToken,
        },
      );
      final response = await _client.get(uri);
      _check(response);
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      for (final document in (body['documents'] as List?) ?? const []) {
        names.add((document as Map<String, dynamic>)['name'] as String);
      }
      pageToken = body['nextPageToken'] as String?;
    } while (pageToken != null);
    return names;
  }

  /// Deletes the documents with these full [names].
  Future<void> delete(List<String> names) async {
    // A commit takes at most 500 writes.
    for (var i = 0; i < names.length; i += 500) {
      await _commit([
        for (final name in names.skip(i).take(500)) {'delete': name},
      ]);
    }
  }

  /// Applies [writes] (Firestore REST write objects) in one commit.
  Future<void> _commit(List<Map<String, Object>> writes) async {
    if (writes.isEmpty) return;
    final response = await _client.post(
      Uri.parse('$_base/$_database/documents:commit'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'writes': writes}),
    );
    _check(response);
  }

  /// Exits with Firestore's message unless [response] succeeded.
  static void _check(http.Response response) {
    if (response.statusCode != 200) {
      _fail('Firestore said ${response.statusCode}: ${response.body}');
    }
  }
}

/// The emulator accepts the "owner" token, which bypasses the rules like an
/// admin.
class _EmulatorClient extends http.BaseClient {
  final _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['authorization'] = 'Bearer owner';
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}

// ---- helpers ---------------------------------------------------------------

/// Returns the value after the option [name] in [args], or null if absent.
String? _option(List<String> args, String name) {
  final i = args.indexOf(name);
  return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
}

/// Prints [message] to stderr and exits with status 1.
Never _fail(String message) {
  stderr.writeln(message);
  exit(1);
}
