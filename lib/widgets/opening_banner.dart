import 'package:flutter/material.dart';
import '../models/opening.dart';

class OpeningBanner extends StatefulWidget {
  final Opening? opening;

  const OpeningBanner({super.key, this.opening});

  @override
  State<OpeningBanner> createState() => _OpeningBannerState();
}

class _OpeningBannerState extends State<OpeningBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  Opening? _displayed;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    if (widget.opening != null) {
      _displayed = widget.opening;
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(OpeningBanner old) {
    super.didUpdateWidget(old);
    if (widget.opening?.name != old.opening?.name) {
      if (widget.opening != null) {
        _displayed = widget.opening;
        _controller.forward(from: 0);
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_displayed == null) return const SizedBox.shrink();

    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1A2744), Color(0xFF0D1B2A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFF4B942).withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text('♟ ', style: TextStyle(fontSize: 16)),
                Text(
                  _displayed!.name,
                  style: const TextStyle(
                    color: Color(0xFFF4B942),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4B942).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _displayed!.eco,
                    style: const TextStyle(
                      color: Color(0xFFF4B942),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _displayed!.description,
              style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 4),
            Text(
              '📋 Plan: ${_displayed!.plan}',
              style: const TextStyle(
                color: Color(0xFF90CAF9),
                fontSize: 11,
                height: 1.4,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
