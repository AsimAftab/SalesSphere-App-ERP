import 'dart:io';

/// Image formats the backend's customer-images endpoint accepts.
/// Backend mime filter is the source of truth — keep this in sync if
/// it widens.
const Set<String> _kAllowedImageExtensions = <String>{
  'jpg',
  'jpeg',
  'png',
};

/// Max file size the backend accepts on `POST /customers/{id}/images`
/// (Multer is configured at `5 * 1024 * 1024` bytes). Files above
/// this trip the backend's catch-all 500 because Multer's
/// `LIMIT_FILE_SIZE` error isn't translated specifically — we'd
/// rather reject locally with a clear message.
const int kMaxImageBytes = 5 * 1024 * 1024;

/// Suggested upper bound for `image_picker`'s `maxWidth` / `maxHeight`.
/// Combined with `imageQuality: 80` this keeps the vast majority of
/// modern phone-camera JPEGs well under [kMaxImageBytes] without
/// visible quality loss when displayed on a 2-image gallery card.
const double kPickerMaxDimension = 2400;

/// User-facing rejection copy. Centralised so add/edit forms (and
/// potential future image entry points) phrase it identically.
const String kUnsupportedImageMessage =
    'Only JPEG and PNG images are supported.';

String imageTooLargeMessage(int actualBytes) {
  final mb = (actualBytes / (1024 * 1024)).toStringAsFixed(1);
  final cap = (kMaxImageBytes / (1024 * 1024)).toStringAsFixed(0);
  return 'Image too large ($mb MB). Maximum size is $cap MB.';
}

/// Returns `true` when [path]'s extension is one of the accepted
/// formats. Case-insensitive; treats a missing extension as a
/// rejection so the server is never asked to guess.
bool isAllowedImageFile(String path) {
  final dotIdx = path.lastIndexOf('.');
  if (dotIdx < 0 || dotIdx == path.length - 1) return false;
  final ext = path.substring(dotIdx + 1).toLowerCase();
  return _kAllowedImageExtensions.contains(ext);
}

/// Stat the file at [path]. Returns the byte count, or `null` if the
/// file disappeared between the pick and this check (rare; race with
/// the temp-file cleaner on low-storage devices).
Future<int?> imageFileBytes(String path) async {
  try {
    return await File(path).length();
  } on FileSystemException {
    return null;
  }
}
