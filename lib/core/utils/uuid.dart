import 'dart:math';

/// Generate a v4 UUID string. Used for outbox idempotency keys and local
/// entity ids (e.g. `local_<uuid>`) for optimistically-inserted rows.
///
/// Hand-rolled to avoid pulling the `uuid` package for one site — the
/// algorithm is RFC 4122 §4.4: 16 random bytes with version (4) and
/// variant (10xx) bits set, formatted as 8-4-4-4-12 hex.
String generateUuidV4() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant 10xx
  String hex(int b) => b.toRadixString(16).padLeft(2, '0');
  final s = bytes.map(hex).join();
  return '${s.substring(0, 8)}-'
      '${s.substring(8, 12)}-'
      '${s.substring(12, 16)}-'
      '${s.substring(16, 20)}-'
      '${s.substring(20)}';
}
