import 'package:flutter/material.dart';

import 'package:on_go_console_backend/console_backend.dart';
import '../theme/console_theme.dart';
import 'console_formats.dart';
import 'console_widgets.dart';

/// How the console shows the files attached to a verification request.
///
/// A reviewer is deciding whether someone is who they say they are, so the ID
/// is always separated from the credentials being claimed rather than dropped
/// into one undifferentiated list. That grouping is the whole reason
/// [CredentialKind] exists.
class CredentialGroupView extends StatelessWidget {
  final CredentialKind kind;
  final List<CredentialDocument> documents;

  const CredentialGroupView({
    super.key,
    required this.kind,
    required this.documents,
  });

  @override
  Widget build(BuildContext context) {
    if (documents.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConsoleSectionLabel(kind.label),
        for (final document in documents)
          CredentialRowView(document: document, kind: kind),
        const SizedBox(height: 14),
      ],
    );
  }
}

/// One file: what it is, what it was called, and a way to open it.
class CredentialRowView extends StatelessWidget {
  final CredentialDocument document;
  final CredentialKind kind;

  const CredentialRowView({super.key, required this.document, required this.kind});

  IconData get _icon => switch (kind) {
        CredentialKind.mechanicId => Icons.badge_outlined,
        CredentialKind.document => Icons.description_outlined,
        CredentialKind.certification => Icons.workspace_premium_outlined,
      };

  Color get _color =>
      kind == CredentialKind.mechanicId ? ConsoleColors.info : ConsoleColors.success;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: ConsoleColors.surfaceMuted,
        borderRadius: ConsoleMetrics.borderRadius,
        border: Border.all(color: ConsoleColors.border),
      ),
      child: Row(
        children: [
          Icon(_icon, size: 18, color: _color),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(document.label, style: text.titleSmall),
                Text(
                  '${document.fileName} · uploaded ${formatConsoleDate(document.uploadedAt)}',
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => showCredentialPreview(context, document),
            child: const Text('Open'),
          ),
        ],
      ),
    );
  }
}

/// Opens a file.
///
/// The console has a reference to the upload, not the bytes — those sit on the
/// device that made them until the backend serves them. So this reports
/// exactly what is known rather than rendering a placeholder that looks like a
/// failed image: a reviewer needs to be able to tell "cannot load this yet"
/// from "this document is blank".
void showCredentialPreview(BuildContext context, CredentialDocument document) {
  showDialog<void>(
    context: context,
    builder: (ctx) {
      final text = Theme.of(ctx).textTheme;
      return AlertDialog(
        insetPadding: consoleDialogInsets(ctx),
        title: Text(document.label),
        content: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: ConsoleLayout.of(ctx).dialogWidth(460)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(document.fileName, style: text.bodySmall),
              const SizedBox(height: 16),
              Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: ConsoleColors.surfaceMuted,
                  borderRadius: ConsoleMetrics.borderRadius,
                  border: Border.all(color: ConsoleColors.border),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      document.isPdf
                          ? Icons.picture_as_pdf_outlined
                          : document.isImage
                              ? Icons.image_outlined
                              : Icons.insert_drive_file_outlined,
                      size: 40,
                      color: ConsoleColors.textMuted,
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'This file is stored on the device that uploaded it. '
                        'The console can open it once uploads are served by the API.',
                        textAlign: TextAlign.center,
                        style: text.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ConsoleField(label: 'Reference', value: document.uri),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      );
    },
  );
}

/// The documents panel inside a review sheet.
///
/// Prefers the real uploads and falls back to the file names registration
/// reported, which is all there is for a request that reached the console
/// before uploads were served.
class RequestDocumentsView extends StatelessWidget {
  final AccountVerificationRequest request;

  const RequestDocumentsView({super.key, required this.request});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    if (request.documents.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final kind in CredentialKind.values)
            CredentialGroupView(kind: kind, documents: request.documentsOfKind(kind)),
        ],
      );
    }

    if (request.documentNames.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text('No documents submitted.', style: text.bodySmall),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final name in request.documentNames)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: ConsoleColors.surfaceMuted,
              borderRadius: ConsoleMetrics.borderRadius,
              border: Border.all(color: ConsoleColors.border),
            ),
            child: Row(
              children: [
                Icon(
                  name.toLowerCase().endsWith('.pdf')
                      ? Icons.picture_as_pdf_outlined
                      : Icons.image_outlined,
                  size: 18,
                  color: ConsoleColors.textMuted,
                ),
                const SizedBox(width: 11),
                Expanded(child: Text(name, style: text.bodyMedium)),
              ],
            ),
          ),
        const SizedBox(height: 4),
        Text(
          'File names only — the uploads themselves reach the console through '
          'the API.',
          style: text.bodySmall,
        ),
      ],
    );
  }
}
