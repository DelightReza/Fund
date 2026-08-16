import 'package:flutter/material.dart';

enum StatusPopupType {
  success,
  error,
  processing,
  info,
}

class StatusPopup {
  static Future<void> show(
    BuildContext context, {
    required String title,
    required String message,
    StatusPopupType type = StatusPopupType.info,
    String? actionLabel,
    VoidCallback? onAction,
    Duration? autoDismissDuration,
  }) async {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: title,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (context, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnim = CurvedAnimation(parent: animation, curve: Curves.easeOutBack);
        return ScaleTransition(
          scale: Tween<double>(begin: 0.85, end: 1.0).animate(curvedAnim),
          child: FadeTransition(
            opacity: animation,
            child: _StatusPopupDialog(
              title: title,
              message: message,
              type: type,
              actionLabel: actionLabel,
              onAction: onAction,
              autoDismissDuration: autoDismissDuration,
            ),
          ),
        );
      },
    );
  }
}

class _StatusPopupDialog extends StatefulWidget {
  const _StatusPopupDialog({
    required this.title,
    required this.message,
    required this.type,
    this.actionLabel,
    this.onAction,
    this.autoDismissDuration,
  });

  final String title;
  final String message;
  final StatusPopupType type;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Duration? autoDismissDuration;

  @override
  State<_StatusPopupDialog> createState() => _StatusPopupDialogState();
}

class _StatusPopupDialogState extends State<_StatusPopupDialog> with SingleTickerProviderStateMixin {
  late AnimationController _iconAnimCtrl;

  @override
  void initState() {
    super.initState();
    _iconAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    if (widget.autoDismissDuration != null) {
      Future.delayed(widget.autoDismissDuration!, () {
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      });
    }
  }

  @override
  void dispose() {
    _iconAnimCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (Color primaryColor, Color bgColor, IconData icon) = switch (widget.type) {
      StatusPopupType.success => (
          const Color(0xFF10B981),
          const Color(0xFFECFDF5),
          Icons.check_circle_rounded,
        ),
      StatusPopupType.error => (
          const Color(0xFFEF4444),
          const Color(0xFFFEF2F2),
          Icons.error_rounded,
        ),
      StatusPopupType.processing => (
          const Color(0xFF3B82F6),
          const Color(0xFFEFF6FF),
          Icons.sync_rounded,
        ),
      StatusPopupType.info => (
          const Color(0xFF6366F1),
          const Color(0xFFEEF2FF),
          Icons.info_rounded,
        ),
    };

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final resolvedBg = isDark ? primaryColor.withOpacity(0.15) : bgColor;

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
          border: Border.all(
            color: Theme.of(context).dividerColor.withOpacity(0.12),
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: CurvedAnimation(
                parent: _iconAnimCtrl,
                curve: Curves.elasticOut,
              ),
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: resolvedBg,
                  shape: BoxShape.circle,
                ),
                child: widget.type == StatusPopupType.processing
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                        ),
                      )
                    : Icon(icon, color: primaryColor, size: 36),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(widget.actionLabel != null ? 'Dismiss' : 'Close'),
                  ),
                ),
                if (widget.actionLabel != null && widget.onAction != null) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        widget.onAction!();
                      },
                      child: Text(widget.actionLabel!),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
