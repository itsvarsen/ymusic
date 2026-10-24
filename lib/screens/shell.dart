import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/library.dart';
import '../theme.dart';
import '../widgets/glass.dart';
import '../widgets/mini_player.dart';
import 'home_tab.dart';
import 'library_tab.dart';
import 'search_tab.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _index != 0) setState(() => _index = 0);
      },
      child: Scaffold(
        backgroundColor: YColors.bg,
        resizeToAvoidBottomInset: false,
        body: AmbientBackground(
          child: Stack(
            children: [
              Positioned.fill(
                child: IndexedStack(
                  index: _index,
                  children: [
                    HomeTab(onOpenLibrary: () => setState(() => _index = 1)),
                    const LibraryTab(),
                    SearchTab(active: _index == 2),
                  ],
                ),
              ),
              const Positioned(left: 0, right: 0, top: 0, child: _ImportBanner()),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const MiniPlayer(),
                    GlassNavBar(index: _index, onChanged: (i) => setState(() => _index = i)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small glass banner shown while an import runs.
class _ImportBanner extends StatelessWidget {
  const _ImportBanner();
  @override
  Widget build(BuildContext context) {
    final lib = context.read<LibraryStore>();
    return ValueListenableBuilder(
      valueListenable: lib.importProgress,
      builder: (context, p, _) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: p == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  key: const ValueKey('import'),
                  padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top + 6, 16, 0),
                  child: Glass(
                    radius: 22,
                    opacity: 0.75,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Adding ${p.done + 1} of ${p.total}',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                        const SizedBox(height: 2),
                        Text(p.current,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: YColors.muted, fontSize: 12)),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: p.total == 0 ? null : (p.done / p.total),
                            minHeight: 3,
                            color: YColors.amber,
                            backgroundColor: const Color(0x1FFFF1E0),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }
}

/// Top bar shared by tabs: wordmark + add button.
class TabTopBar extends StatelessWidget {
  final Widget? title;
  final List<Widget> actions;
  const TabTopBar({super.key, this.title, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(22, MediaQuery.paddingOf(context).top + 12, 14, 6),
      child: Row(
        children: [
          Expanded(child: title ?? const Align(alignment: Alignment.centerLeft, child: BrandMark())),
          ...actions,
        ],
      ),
    );
  }
}

/// Empty library state with a big "Add music" button.
class EmptyLibrary extends StatelessWidget {
  final VoidCallback onAdd;
  const EmptyLibrary({super.key, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 0, 32, 140),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 132,
              height: 132,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(colors: [Color(0x55F2A65A), Color(0x00F2A65A)]),
                border: Border.all(color: const Color(0x22FFF1E0)),
              ),
              child: const Icon(Icons.graphic_eq_rounded, size: 56, color: YColors.amber),
            ),
            const SizedBox(height: 26),
            const Text('Your music, only yours',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
            const SizedBox(height: 10),
            const Text(
              'Pick the songs you want. ⅄music never scans your phone; it only plays what you add.',
              textAlign: TextAlign.center,
              style: TextStyle(color: YColors.muted, fontSize: 14.5, height: 1.45),
            ),
            const SizedBox(height: 28),
            PillButton(label: 'Add music', icon: Icons.add_rounded, large: true, onTap: onAdd),
          ],
        ),
      ),
    );
  }
}
