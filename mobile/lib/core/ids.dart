import 'dart:math';

const _alphabet = '0123456789abcdefghjkmnpqrstvwxyz';

/// Generates a ULID-compatible, lexicographically sortable 26-character ID.
///
/// The server accepts client-generated IDs for offline creates, so the mobile
/// client owns identity for anything it creates while offline.
String newSyncId([DateTime? now]) {
  final millis = (now ?? DateTime.now().toUtc()).millisecondsSinceEpoch;
  final random = Random.secure();
  final out = List<int>.filled(26, 0);
  var value = millis;
  for (var i = 9; i >= 0; i--) {
    out[i] = _alphabet.codeUnitAt(value & 31);
    value >>= 5;
  }
  for (var i = 10; i < 26; i++) {
    out[i] = _alphabet.codeUnitAt(random.nextInt(32));
  }
  return String.fromCharCodes(out);
}
