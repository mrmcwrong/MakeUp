import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'debug_time.dart';

class DebugOverlay extends StatefulWidget {
  final Widget child;
  final VoidCallback onUpdate;

  const DebugOverlay({
    super.key,
    required this.child,
    required this.onUpdate,
  });

  @override
  State<DebugOverlay> createState() => _DebugOverlayState();
}

class _DebugOverlayState extends State<DebugOverlay> {
  bool _showPanel = false;
  bool _fastForwardActive = false;
  int _tapCount = 0;
  DateTime? _lastTap;

  // ── Tap 5 times on the bug icon to show/hide the panel ──────────────────────
  void _handleTap() {
    final now = DateTime.now(); // always use real time for UI interactions
    if (_lastTap != null &&
        now.difference(_lastTap!) > const Duration(seconds: 2)) {
      _tapCount = 0;
    }
    _lastTap = now;
    _tapCount++;

    if (_tapCount >= 5) {
      setState(() {
        _showPanel = !_showPanel;
        _tapCount = 0;
      });
    }
  }

  // ── Toggle fast-forward ──────────────────────────────────────────────────────
  void _toggleFastForward() {
    final nowActive = !_fastForwardActive;
    if (nowActive) {
      DebugTime.enable();
    } else {
      DebugTime.disable();
    }
    setState(() {
      _fastForwardActive = nowActive;
    });
    _showSnack(nowActive
        ? 'Fast-forward ON — 1 day every 5 seconds ⏩'
        : 'Fast-forward OFF — back to real time');
    // Defer parent rebuild until after this frame so the button updates instantly
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.onUpdate());
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Directionality(
          textDirection: TextDirection.ltr,
          child: Text(message, style: GoogleFonts.dmSans()),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final fastForwardActive = _fastForwardActive;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          widget.child,

          // ── Bug icon (tap 5× to reveal panel) ─────────────────────────────
          Positioned(
            top: 40,
            right: 10,
            child: GestureDetector(
              onTap: _handleTap,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _showPanel
                      ? Colors.red.withValues(alpha: 0.5)
                      : Colors.grey.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.grey.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.bug_report,
                    size: 20,
                    color: _showPanel
                        ? Colors.red
                        : Colors.grey.withValues(alpha: 0.3),
                  ),
                ),
              ),
            ),
          ),

          // ── Debug panel ────────────────────────────────────────────────────
          if (_showPanel)
            Positioned(
              top: 88,
              right: 10,
              child: Material(
                type: MaterialType.transparency,
                child: Container(
                  width: 220,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.red, width: 2),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Title
                      Text(
                        'DEBUG TOOLS',
                        style: GoogleFonts.dmSans(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),

                      // Status line
                      Text(
                        fastForwardActive
                            ? '⏩ 1 day / 5 seconds'
                            : '🕐 Real time',
                        style: GoogleFonts.dmSans(
                          color: fastForwardActive
                              ? Colors.orangeAccent
                              : Colors.grey,
                          fontSize: 11,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),

                      // Fast-forward toggle
                      _buildButton(
                        fastForwardActive
                            ? 'Stop Fast-Forward'
                            : 'Start Fast-Forward ⏩',
                        _toggleFastForward,
                        color: fastForwardActive
                            ? Colors.orange[800]
                            : Colors.green[800],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildButton(String label, VoidCallback onPressed, {Color? color}) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color ?? Colors.grey[800],
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 10),
        textStyle: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(label),
    );
  }
}