import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/game_state.dart';
import 'game_screen.dart';
import 'history_screen.dart';
import 'progress_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  PlayerColor _playerColor = PlayerColor.white;
  int _difficulty = 3;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 20),
              // Logo / Title
              const _Logo(),

              const SizedBox(height: 40),

              // Coaching status
              const _LocalCoachingBanner(),

              const SizedBox(height: 32),

              // Color picker
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Play as',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ),
              const SizedBox(height: 8),
              _ColorPicker(
                selected: _playerColor,
                onSelect: (c) => setState(() => _playerColor = c),
              ),

              const SizedBox(height: 24),

              // Difficulty picker
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Difficulty',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ),
              const SizedBox(height: 8),
              _DifficultyPicker(
                selected: _difficulty,
                onSelect: (d) => setState(() => _difficulty = d),
              ),

              const Spacer(),

              // Play button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _startGame,
                  icon: const Text('♟', style: TextStyle(fontSize: 20)),
                  label: const Text(
                    'Play',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF4B942),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 4,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // History / Progress row
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const HistoryScreen()),
                      ),
                      icon: const Icon(Icons.history, size: 18),
                      label: const Text('History'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Color(0xFF1E3A5F)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ProgressScreen()),
                      ),
                      icon: const Icon(Icons.trending_up, size: 18),
                      label: const Text('Progress'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFF4B942),
                        side: const BorderSide(color: Color(0xFFF4B942), width: 1),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _startGame() {
    // Start the game via the notifier, then navigate
    final notifier = ref.read(gameNotifierProvider.notifier);
    notifier.startGame(playerColor: _playerColor, difficulty: _difficulty);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GameScreen(playerColor: _playerColor, difficulty: _difficulty),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text('♟', style: TextStyle(fontSize: 64)),
        const SizedBox(height: 8),
        const Text(
          'Chess Coach',
          style: TextStyle(
            color: Color(0xFFF4B942),
            fontSize: 28,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'AI-powered coaching for every move',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class _LocalCoachingBanner extends StatelessWidget {
  const _LocalCoachingBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.offline_bolt, color: Colors.greenAccent, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Local coaching active — no internet or API key needed',
              style: TextStyle(color: Colors.greenAccent, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorPicker extends StatelessWidget {
  final PlayerColor selected;
  final void Function(PlayerColor) onSelect;

  const _ColorPicker({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ColorOption(
            label: 'White',
            symbol: '♔',
            isSelected: selected == PlayerColor.white,
            onTap: () => onSelect(PlayerColor.white),
            symbolColor: Colors.white,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ColorOption(
            label: 'Black',
            symbol: '♚',
            isSelected: selected == PlayerColor.black,
            onTap: () => onSelect(PlayerColor.black),
            symbolColor: Colors.black87,
          ),
        ),
      ],
    );
  }
}

class _ColorOption extends StatelessWidget {
  final String label;
  final String symbol;
  final bool isSelected;
  final VoidCallback onTap;
  final Color symbolColor;

  const _ColorOption({
    required this.label,
    required this.symbol,
    required this.isSelected,
    required this.onTap,
    required this.symbolColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFF4B942).withValues(alpha: 0.15)
              : const Color(0xFF0D2137),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFFF4B942) : const Color(0xFF1E3A5F),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: label == 'White' ? Colors.white : Colors.black,
                border: Border.all(color: Colors.white24),
              ),
              child: Center(
                child: Text(symbol, style: TextStyle(fontSize: 22, color: symbolColor)),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFFF4B942) : Colors.white54,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DifficultyPicker extends StatelessWidget {
  final int selected;
  final void Function(int) onSelect;

  const _DifficultyPicker({required this.selected, required this.onSelect});

  static const labels = {1: 'Novice', 2: 'Beginner', 3: 'Casual', 4: 'Club', 5: 'Master'};

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(5, (i) {
            final d = i + 1;
            final sel = d == selected;
            return GestureDetector(
              onTap: () => onSelect(d),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: sel
                      ? const Color(0xFFF4B942)
                      : const Color(0xFF0D2137),
                  border: Border.all(
                    color: sel ? const Color(0xFFF4B942) : const Color(0xFF1E3A5F),
                  ),
                ),
                child: Center(
                  child: Text(
                    '$d',
                    style: TextStyle(
                      color: sel ? Colors.black : Colors.white54,
                      fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 6),
        Text(
          labels[selected] ?? 'Level $selected',
          style: const TextStyle(color: Color(0xFFF4B942), fontSize: 13),
        ),
      ],
    );
  }
}
