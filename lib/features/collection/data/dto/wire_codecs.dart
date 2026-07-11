/// Wire codecs shared by both collection modules.
///
/// Small enough to be tempting to inline, and exactly the kind of thing that
/// must not be: get any of these wrong and money or dates are silently wrong
/// rather than loudly broken.
library;

/// Money arrives as a decimal **string** (`"20000.00"`, `Decimal.toFixed(2)`)
/// and is sent back as a JSON **number**. That asymmetry is the single easiest
/// thing to get wrong on this contract — a naive `as num` cast throws on every
/// read.
///
/// A raw number is tolerated too, so a locally-built draft can round-trip
/// through drift without going near the wire.
double parseMoney(Object? raw) {
  if (raw is num) return raw.toDouble();
  if (raw is String) return double.tryParse(raw) ?? 0;
  return 0;
}

/// Parse a bare `yyyy-MM-dd` calendar day into a local-midnight [DateTime]
/// whose Y/M/D match the server's stored day regardless of device timezone.
///
/// `receivedDate` and `chequeDate` are calendar days. `createdAt` / `updatedAt`
/// are full ISO timestamps and must NOT go through this — two formats, two
/// codecs.
DateTime parseWireDate(String raw) {
  final d = DateTime.parse(raw);
  return DateTime(d.year, d.month, d.day);
}

/// Wire format for a calendar day: a bare `yyyy-MM-dd`, with no timezone to
/// drift.
///
/// **Never "improve" this into an ISO instant.** The server takes a date-only
/// string at face value and asks "is this in the future" against *today in the
/// org's timezone*. Sending a UTC instant instead caused a live bug that
/// rejected every receipt recorded in Nepal between midnight and 05:45 — the
/// early field round — with "Received date cannot be in the future", because
/// the day had already rolled over in UTC.
String dateToWire(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
