import 'package:flutter/material.dart';
import '../models/game_state.dart';

class CoachingPanel extends StatefulWidget {
  final GameState gameState;

  const CoachingPanel({super.key, required this.gameState});

  @override
  State<CoachingPanel> createState() => _CoachingPanelState();
}

class _CoachingPanelState extends State<CoachingPanel> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final gs = widget.gameState;
    final hasContent = gs.aiMoveExplanation != null ||
        gs.lastCoachingTip != null ||
        gs.blunderWarning != null ||
        gs.isAiThinking ||
        gs.isLoadingCoaching;

    if (!hasContent) return const SizedBox.shrink();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0D2137),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E3A5F), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.school, color: Color(0xFFF4B942), size: 18),
                  const SizedBox(width: 8),
                  const Text(
                    'Chess Coach',
                    style: TextStyle(
                      color: Color(0xFFF4B942),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: const Color(0xFFF4B942),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1, color: Color(0xFF1E3A5F)),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (gs.blunderWarning != null)
                    _TipRow(
                      icon: Icons.warning_amber_rounded,
                      color: Colors.orange,
                      text: gs.blunderWarning!,
                    ),
                  if (gs.isAiThinking)
                    const _LoadingRow(text: 'AI is thinking...'),
                  if (gs.aiMoveExplanation != null)
                    _TipRow(
                      icon: Icons.smart_toy_outlined,
                      color: const Color(0xFF64B5F6),
                      text: gs.aiMoveExplanation!,
                    ),
                  if (gs.isLoadingCoaching && gs.lastCoachingTip == null)
                    const _LoadingRow(text: 'Coach is analyzing...'),
                  if (gs.lastCoachingTip != null)
                    _TipRow(
                      icon: Icons.lightbulb_outline,
                      color: const Color(0xFFF4B942),
                      text: gs.lastCoachingTip!,
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TipRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _TipRow({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingRow extends StatelessWidget {
  final String text;

  const _LoadingRow({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF4B942)),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            text,
            style: const TextStyle(color: Colors.white38, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
