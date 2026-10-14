import 'package:flutter/material.dart';
import '../screens/app_theme.dart' show appFontFamily;

class TransactionSheetColors {
  static const background = Color(0xFFF6F9FF);
  static const ink = Color(0xFF3D568F);
  static const muted = Color(0xFF8493B3);
  static const accent = Color(0xFFC1E4F3);
  static const red = Color(0xFFE0645F);
  static const green = Color(0xFF3D9E73);
}

/// Scrolls on small screens and keeps actions above the keyboard.
class TransactionSheetFrame extends StatelessWidget {
  const TransactionSheetFrame(
      {super.key,
      required this.title,
      required this.child,
      required this.actions,
      this.busy = false});
  final String title;
  final Widget child;
  final Widget actions;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: (media.size.height -
                    media.viewInsets.bottom -
                    media.padding.top -
                    16)
                .clamp(0, double.infinity)),
        child: Material(
          color: TransactionSheetColors.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
              top: false,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 12, 8),
                    child: Row(children: [
                      Expanded(
                          child: Text(title,
                              style: const TextStyle(
                                  color: TransactionSheetColors.ink,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700))),
                      IconButton.filled(
                          onPressed: busy ? null : () => Navigator.pop(context),
                          tooltip: MaterialLocalizations.of(context)
                              .closeButtonTooltip,
                          style: IconButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: TransactionSheetColors.muted),
                          icon: const Icon(Icons.close_rounded)),
                    ])),
                Flexible(
                    child: SingleChildScrollView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: child)),
                Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                    child: actions),
              ])),
        ),
      ),
    );
  }
}

Widget transactionWhiteCard({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(18)),
    child: child);

ButtonStyle transactionActionStyle(
        {bool primary = false, bool destructive = false}) =>
    FilledButton.styleFrom(
      backgroundColor: primary ? TransactionSheetColors.accent : Colors.white,
      foregroundColor:
          destructive ? TransactionSheetColors.red : TransactionSheetColors.ink,
      disabledBackgroundColor:
          TransactionSheetColors.accent.withValues(alpha: 0.5),
      minimumSize: const Size(0, 48),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      shape: const StadiumBorder(),
      textStyle: const TextStyle(fontFamily: appFontFamily, fontSize: 14, fontWeight: FontWeight.w700),
    );
