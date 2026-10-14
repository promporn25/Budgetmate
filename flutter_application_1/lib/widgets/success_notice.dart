import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/data_service.dart';

final _notices = Expando<OverlayEntry>('success notices');

/// Display above the navigator so closing a sheet or changing routes keeps it visible.
void showSuccessNotice(BuildContext context, String messageKey) {
  final service = context.read<DataService>();
  if (!service.successNotesEnabled) return;
  final overlay = Overlay.of(context, rootOverlay: true);
  final message = service.t(messageKey);
  final dismissLabel = service.t('dismiss_success_notice');
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!overlay.mounted) return;
    final previous = _notices[overlay];
    if (previous != null) {
      previous.remove();
      previous.dispose();
    }
    late final OverlayEntry entry;
    void dismiss() {
      if (_notices[overlay] != entry) return;
      _notices[overlay] = null;
      entry.remove();
      entry.dispose();
    }

    entry = OverlayEntry(
      builder: (_) => Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: SafeArea(
          bottom: false,
          minimum: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: _SuccessNotice(
                  message: message,
                  dismissLabel: dismissLabel,
                  onDismiss: dismiss),
            ),
          ),
        ),
      ),
    );
    _notices[overlay] = entry;
    overlay.insert(entry);
  });
  WidgetsBinding.instance.ensureVisualUpdate();
}

class _SuccessNotice extends StatefulWidget {
  const _SuccessNotice(
      {required this.message,
      required this.dismissLabel,
      required this.onDismiss});
  final String message;
  final String dismissLabel;
  final VoidCallback onDismiss;

  @override
  State<_SuccessNotice> createState() => _SuccessNoticeState();
}

class _SuccessNoticeState extends State<_SuccessNotice> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 4), widget.onDismiss);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        child: Material(
          color: const Color(0xFF216746),
          elevation: 8,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
            child: Row(children: [
              const Icon(Icons.check_circle_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(widget.message,
                    style: const TextStyle(color: Colors.white, fontSize: 15)),
              ),
              IconButton(
                tooltip: widget.dismissLabel,
                onPressed: widget.onDismiss,
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ]),
          ),
        ),
      );
}
