import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../app/console_shell.dart';
import 'package:on_go_console_backend/console_backend.dart';
import '../../session/console_session.dart';
import '../../theme/console_theme.dart';
import '../../widgets/console_formats.dart';
import '../../widgets/console_widgets.dart';

/// Sets the photo behind the mobile app's Sign In and Welcome screens.
///
/// The clearest crossing in the product: an admin picks an image on a website
/// and phones that have never met that website have to start painting it. It
/// goes through [PlatformAppearanceApi.publishBackground] for exactly that
/// reason.
///
/// Picking stages a preview and changes nothing. Publishing is the only thing
/// that writes, which keeps the "are you sure" moment where it belongs. And
/// because the API is not connected yet, the screen says plainly how far a
/// publish actually reaches today rather than implying phones have it.
class ChangeBackgroundPage extends StatefulWidget {
  const ChangeBackgroundPage({super.key});

  @override
  State<ChangeBackgroundPage> createState() => _ChangeBackgroundPageState();
}

class _ChangeBackgroundPageState extends State<ChangeBackgroundPage> {
  Uint8List? _pendingBytes;
  String? _pendingName;
  bool _busy = false;

  bool get _allowed => ConsoleSession.instance.permissions.canChangeBackground;

  Future<void> _choose() async {
    setState(() => _busy = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      final file = result?.files.singleOrNull;
      final bytes = file?.bytes;
      if (bytes == null) return;
      if (!mounted) return;
      setState(() {
        _pendingBytes = bytes;
        _pendingName = file!.name;
      });
    } catch (error) {
      if (mounted) {
        showConsoleMessage(context, 'Could not read that file: $error', isError: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _publish() async {
    final bytes = _pendingBytes;
    if (bytes == null) return;

    setState(() => _busy = true);
    try {
      await ConsoleBackend.instance.appearance.publishBackground(
        bytes: bytes,
        fileName: _pendingName ?? 'background.jpg',
      );
      if (!mounted) return;
      setState(() {
        _pendingBytes = null;
        _pendingName = null;
      });
      showConsoleMessage(context, 'Background published');
    } on ApiException catch (error) {
      if (mounted) showConsoleMessage(context, error.message, isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clear() async {
    final confirmed = await confirmConsoleAction(
      context,
      title: 'Remove the background photo?',
      message:
          "The app's Sign In and Welcome screens go back to the theme's "
          'background color.',
      confirmLabel: 'Remove',
    );
    if (!confirmed || !mounted) return;

    setState(() => _busy = true);
    try {
      await ConsoleBackend.instance.appearance.clearBackground();
      if (mounted) showConsoleMessage(context, 'Background removed');
    } on ApiException catch (error) {
      if (mounted) showConsoleMessage(context, error.message, isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ConsoleShell(
      title: 'App background',
      subtitle: "The photo behind the mobile app's Sign In and Welcome screens",
      showBackButton: true,
      child: StreamBuilder<PlatformAppearance>(
        stream: ConsoleBackend.instance.appearance.watch(),
        initialData: PlatformAppearance.none,
        builder: (context, snapshot) {
          final appearance = snapshot.data ?? PlatformAppearance.none;
          final publishedBytes =
              ConsoleBackend.instance.localAppearance?.backgroundBytes;
          final shown = _pendingBytes ?? publishedBytes;

          return ListView(
            padding: consolePagePadding(context),
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 860),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!_allowed) const _NoPermissionNotice(),
                    if (!_allowed) SizedBox(height: context.layout.sectionSpacing),
                    ConsoleCard(
                      title: 'Current background',
                      subtitle: appearance.hasBackground
                          ? 'Published ${appearance.updatedAt == null ? 'earlier' : formatConsoleDateTime(appearance.updatedAt!)}'
                          : 'Both screens use the theme background color',
                      child: Builder(
                        builder: (context) {
                          final layout = context.layout;
                          final preview = _PhonePreview(
                            bytes: shown,
                            scale: layout.isPhone ? 0.78 : 1,
                          );
                          final controls = _controls(context, appearance);

                          if (layout.stacksPairs) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Center(child: preview),
                                const SizedBox(height: 24),
                                controls,
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              preview,
                              const SizedBox(width: 28),
                              Expanded(child: controls),
                            ],
                          );
                        },
                      ),
                    ),
                    SizedBox(height: context.layout.sectionSpacing),
                    const _ReachNotice(),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _controls(BuildContext context, PlatformAppearance appearance) {
    final text = Theme.of(context).textTheme;
    final staged = _pendingBytes != null;
    final canAct = _allowed && !_busy;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          staged
              ? 'Preview only — publish to apply it.'
              : appearance.hasBackground
                  ? 'A photo is published.'
                  : 'No photo published.',
          style: text.titleSmall?.copyWith(
            color: staged ? ConsoleColors.warning : ConsoleColors.text,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Choose a wide, uncluttered photo: the app draws its sign-in card over '
          'the lower half of it.',
          style: text.bodySmall,
        ),
        if (_pendingName != null) ...[
          const SizedBox(height: 14),
          ConsoleField(
            icon: Icons.image_outlined,
            label: 'Selected file',
            value: _pendingName!,
          ),
        ],
        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: canAct ? _choose : null,
          icon: const Icon(Icons.photo_library_outlined, size: 17),
          label: Text(
            staged
                ? 'Choose a different photo'
                : appearance.hasBackground
                    ? 'Replace photo'
                    : 'Choose a photo',
          ),
        ),
        const SizedBox(height: 10),
        if (staged) ...[
          ElevatedButton.icon(
            onPressed: canAct ? _publish : null,
            icon: const Icon(Icons.publish_outlined, size: 17),
            label: Text(_busy ? 'Publishing…' : 'Publish'),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: canAct
                ? () => setState(() {
                      _pendingBytes = null;
                      _pendingName = null;
                    })
                : null,
            child: Text('Cancel', style: TextStyle(color: ConsoleColors.textMuted)),
          ),
        ] else
          OutlinedButton.icon(
            onPressed: canAct && appearance.hasBackground ? _clear : null,
            style: OutlinedButton.styleFrom(
              foregroundColor: ConsoleColors.danger,
              side: BorderSide(
                color: appearance.hasBackground
                    ? ConsoleColors.danger.withValues(alpha: 0.45)
                    : ConsoleColors.border,
              ),
            ),
            icon: const Icon(Icons.delete_outline, size: 17),
            label: const Text('Remove photo'),
          ),
      ],
    );
  }
}

/// A miniature of the app's Sign In screen, so the admin sees what they are
/// actually setting rather than a bare image crop.
class _PhonePreview extends StatelessWidget {
  const _PhonePreview({required this.bytes, this.scale = 1});

  final Uint8List? bytes;

  /// Shrinks the mock-up on a phone, where a 300-point preview plus the
  /// controls under it is more than one screen.
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 170 * scale,
      height: 300 * scale,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: ConsoleColors.surfaceMuted,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ConsoleColors.border, width: 2),
        image: bytes == null
            ? null
            : DecorationImage(image: MemoryImage(bytes!), fit: BoxFit.cover),
      ),
      child: Column(
        children: [
          const Spacer(),
          Container(
            width: double.infinity,
            height: 118 * scale,
            padding: EdgeInsets.fromLTRB(14 * scale, 16 * scale, 14 * scale, 0),
            decoration: BoxDecoration(
              color: ConsoleColors.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border.all(color: ConsoleColors.brand, width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(height: 12, color: ConsoleColors.surfaceMuted),
                const SizedBox(height: 8),
                Container(height: 12, color: ConsoleColors.surfaceMuted),
                const SizedBox(height: 12),
                Container(
                  height: 16,
                  decoration: BoxDecoration(
                    color: ConsoleColors.brand,
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NoPermissionNotice extends StatelessWidget {
  const _NoPermissionNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ConsoleColors.warning.withValues(alpha: 0.08),
        borderRadius: ConsoleMetrics.borderRadiusLarge,
        border: Border.all(color: ConsoleColors.warning.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline, size: 18, color: ConsoleColors.warning),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Your admin has not given you permission to change the app '
              'background. You can see what is set, but not change it.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

/// How far a publish reaches right now. This is the kind of thing a screen has
/// to say out loud rather than let someone discover.
class _ReachNotice extends StatelessWidget {
  const _ReachNotice();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ConsoleColors.surfaceMuted,
        borderRadius: ConsoleMetrics.borderRadiusLarge,
        border: Border.all(color: ConsoleColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: ConsoleColors.info),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Not reaching phones yet', style: text.titleSmall),
                const SizedBox(height: 4),
                Text(
                  'The console and the mobile app are separate applications and '
                  'the API between them is not built yet, so a photo published '
                  'here is held in this browser. Once uploads are hosted, the '
                  'same button delivers it to every device — this screen does not '
                  'change.',
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
