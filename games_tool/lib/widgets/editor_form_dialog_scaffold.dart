import 'package:flutter/widgets.dart';
import 'package:flutter_cupertino_desktop_kit/flutter_cupertino_desktop_kit.dart';

class EditorFormDialogScaffold extends StatelessWidget {
  const EditorFormDialogScaffold({
    super.key,
    required this.title,
    required this.description,
    required this.body,
    required this.confirmLabel,
    required this.confirmEnabled,
    required this.onConfirm,
    required this.onCancel,
    this.liveEditMode = false,
    this.onClose,
    this.closeLabel = 'Close',
    this.onDelete,
    this.minWidth = 360,
    this.maxWidth = 520,
  });

  final String title;
  final String description;
  final Widget body;
  final String confirmLabel;
  final bool confirmEnabled;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  final bool liveEditMode;
  final VoidCallback? onClose;
  final String closeLabel;
  final VoidCallback? onDelete;
  final double minWidth;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final spacing = CDKThemeNotifier.spacingTokensOf(context);
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      clipBehavior: Clip.none,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: minWidth, maxWidth: maxWidth),
        child: Padding(
          padding: EdgeInsets.all(spacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CDKText(title, role: CDKTextRole.title),
              SizedBox(height: spacing.md),
              if (description.trim().isNotEmpty) ...[
                CDKText(description, role: CDKTextRole.body),
                SizedBox(height: spacing.md),
              ],
              body,
              SizedBox(height: spacing.lg + spacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (onDelete != null)
                    CDKButton(
                      style: CDKButtonStyle.destructive,
                      onPressed: onDelete,
                      child: const Text('Delete'),
                    )
                  else
                    const SizedBox.shrink(),
                  if (liveEditMode)
                    const SizedBox.shrink()
                  else
                    Row(
                      children: [
                        CDKButton(
                          style: CDKButtonStyle.normal,
                          onPressed: onCancel,
                          child: const Text('Cancel'),
                        ),
                        SizedBox(width: spacing.md),
                        CDKButton(
                          style: CDKButtonStyle.action,
                          enabled: confirmEnabled,
                          onPressed: onConfirm,
                          child: Text(confirmLabel),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
