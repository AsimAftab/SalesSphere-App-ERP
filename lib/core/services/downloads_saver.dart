import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'downloads_saver.g.dart';

/// Persists generated files (e.g. order / estimate PDFs) into the device's
/// public **Downloads** folder in a Google-Play-compliant way — with no
/// broad storage permission on modern Android.
///
/// The heavy lifting is done natively (see `MainActivity.kt`) behind the
/// `com.salessphere.app/downloads` method channel:
///
/// * **Android 10+ (API 29):** writes through the MediaStore Downloads
///   collection (scoped storage, permissionless) and mirrors an app-specific
///   copy so the saved file has a real path an external viewer can open.
/// * **Android 9 and below:** writes to the public Downloads directory,
///   guarded by the legacy `WRITE_EXTERNAL_STORAGE` grant (declared
///   `maxSdkVersion="28"` in the manifest). The runtime request is handled
///   here on a [_PermissionRequiredException] from the native side.
class DownloadsSaver {
  const DownloadsSaver();

  static const MethodChannel _channel = MethodChannel(
    'com.salessphere.app/downloads',
  );

  /// Saves [bytes] as [fileName] into the Downloads folder and returns the
  /// local path of an openable copy.
  ///
  /// Throws [DownloadsPermissionException] when the legacy storage
  /// permission is denied (pre-Android-10 only), or [DownloadsSaveException]
  /// on any other failure.
  Future<String> save({
    required String fileName,
    required Uint8List bytes,
    String mimeType = 'application/pdf',
  }) async {
    final args = <String, Object?>{
      'fileName': fileName,
      'bytes': bytes,
      'mimeType': mimeType,
    };
    try {
      return await _invoke(args);
    } on _PermissionRequiredException {
      // Pre-Android-10 devices need the runtime storage grant before the
      // native side can write to the public Downloads directory.
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        throw const DownloadsPermissionException();
      }
      return _invoke(args);
    }
  }

  Future<String> _invoke(Map<String, Object?> args) async {
    try {
      final path = await _channel.invokeMethod<String>(
        'saveToDownloads',
        args,
      );
      if (path == null || path.isEmpty) {
        throw const DownloadsSaveException();
      }
      return path;
    } on PlatformException catch (e) {
      if (e.code == 'PERMISSION_REQUIRED') {
        throw const _PermissionRequiredException();
      }
      throw const DownloadsSaveException();
    } on MissingPluginException {
      throw const DownloadsSaveException();
    }
  }
}

/// Saving failed for a reason the user can't act on (IO error, missing
/// platform channel).
class DownloadsSaveException implements Exception {
  const DownloadsSaveException();

  @override
  String toString() => 'DownloadsSaveException';
}

/// The legacy storage permission was denied on an Android 9-or-below device.
/// Callers should point the user at app settings.
class DownloadsPermissionException implements Exception {
  const DownloadsPermissionException();

  @override
  String toString() => 'DownloadsPermissionException';
}

/// Internal signal that the native side needs the runtime storage permission
/// (pre-Android-10) before it can write to public storage.
class _PermissionRequiredException implements Exception {
  const _PermissionRequiredException();
}

/// Injectable handle to the platform Downloads saver.
@riverpod
DownloadsSaver downloadsSaver(Ref ref) => const DownloadsSaver();
