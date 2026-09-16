import 'dart:typed_data';

import 'package:on_go_shared/on_go_shared.dart';

import 'live_value.dart';

/// The mobile app's Sign In / Welcome background, published from here.
///
/// This is the console's write side of [PlatformAppearanceApi]. There is
/// nowhere to upload to yet, so a published image is held in this browser
/// session and [PlatformAppearance.authBackgroundUrl] carries a `local:`
/// reference naming it — enough for the console to render its own preview, and
/// honestly not a URL the mobile app could fetch.
///
/// Which is the one thing the Change Background screen has to be straight
/// about: until the backend exists, publishing here changes what this console
/// shows and nothing on anyone's phone. The screen says so. When uploads are
/// hosted, this class is replaced by the HTTP implementation, the reference
/// becomes a real URL, and the mobile app's `LocalAppearanceService` starts
/// receiving it — no screen on either side changes.
class LocalAppearanceService implements PlatformAppearanceApi {
  final LiveValue<PlatformAppearance> _appearance =
      LiveValue(PlatformAppearance.none);

  Uint8List? _bytes;

  /// The published image's bytes, for the console's own preview.
  Uint8List? get backgroundBytes => _bytes;

  @override
  Future<PlatformAppearance> fetch() async => _appearance.value;

  @override
  Stream<PlatformAppearance> watch() => _appearance.stream;

  @override
  Future<PlatformAppearance> publishBackground({
    required List<int> bytes,
    required String fileName,
  }) async {
    if (bytes.isEmpty) {
      throw const ApiException(ApiErrorKind.rejected, 'That file was empty.');
    }
    _bytes = Uint8List.fromList(bytes);
    final now = DateTime.now();
    final published = PlatformAppearance(
      // A fresh reference every publish: an unchanged one would let a cache
      // keep serving the previous image.
      authBackgroundUrl: 'local:auth-background/${now.millisecondsSinceEpoch}/$fileName',
      updatedAt: now,
    );
    _appearance.set(published);
    return published;
  }

  @override
  Future<PlatformAppearance> clearBackground() async {
    _bytes = null;
    _appearance.set(PlatformAppearance(updatedAt: DateTime.now()));
    return _appearance.value;
  }
}
