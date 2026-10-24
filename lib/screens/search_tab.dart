import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/library.dart';
import '../services/player.dart';
import '../theme.dart';
import '../widgets/cover.dart';
import '../widgets/glass.dart';
import '../widgets/song_tile.dart';
import 'routes.dart';

class SearchTab extends StatefulWidget {
  final bool active;
  const SearchTab({super.key, required this.active});
  @override
  State<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<SearchTab> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  String _q = '';

  @override
  void didUpdateWidget(covariant SearchTab old) {
    super.didUpdateWidget(old);
    if (!widget.active && _focus.hasFocus) _focus.unfocus();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<LibraryStore>();
    final player = context.read<PlayerController>();
    final r = lib.search(_q);
    final top = MediaQuery.paddingOf(context).top;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => _focus.unfocus(),
      child: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(22, top + 12, 22, 12),
              child: const Text('Search', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -1)),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Glass(
                radius: 22,
                opacity: 0.5,
                child: TextField(
                  controller: _controller,
                  focusNode: _focus,
                  textInputAction: TextInputAction.search,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: 'Songs, artists, albums',
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    prefixIcon: const Icon(Icons.search_rounded, color: YColors.muted),
                    suffixIcon: _q.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close_rounded, color: YColors.muted),
                            onPressed: () {
                              _controller.clear();
                              setState(() => _q = '');
                            },
                          ),
                  ),
                  onChanged: (v) => setState(() => _q = v),
                ),
              ),
            ),
          ),
          if (_q.trim().isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(30, 60, 30, 0),
                child: Column(
                  children: [
                    const Icon(Icons.manage_search_rounded, size: 46, color: YColors.faint),
                    const SizedBox(height: 12),
                    Text(
                      lib.isEmpty ? 'Add some music first' : 'Search across ${songsLabel(lib.songs.length)}',
                      style: const TextStyle(color: YColors.muted),
                    ),
                  ],
                ),
              ),
            )
          else if (r.songs.isEmpty && r.albums.isEmpty && r.artists.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Center(child: Text('Nothing for “$_q”', style: const TextStyle(color: YColors.muted))),
              ),
            )
          else ...[
            if (r.artists.isNotEmpty) ...[
              const SliverToBoxAdapter(child: SectionHeader('Artists')),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 118,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: r.artists.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 16),
                    itemBuilder: (context, i) {
                      final a = r.artists[i];
                      return GestureDetector(
                        onTap: () => openArtist(context, a.name),
                        child: SizedBox(
                          width: 84,
                          child: Column(
                            children: [
                              CoverArt(song: a.coverSong, size: 80, circle: true),
                              const SizedBox(height: 8),
                              Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
            if (r.albums.isNotEmpty) ...[
              const SliverToBoxAdapter(child: SectionHeader('Albums')),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 176,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: r.albums.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 14),
                    itemBuilder: (context, i) {
                      final a = r.albums[i];
                      return GestureDetector(
                        onTap: () => openAlbum(context, a.key),
                        child: SizedBox(
                          width: 120,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CoverArt(song: a.coverSong, size: 120, radius: 20),
                              const SizedBox(height: 8),
                              Text(a.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                              Text(a.artist, maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: YColors.muted, fontSize: 12)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
            if (r.songs.isNotEmpty) ...[
              const SliverToBoxAdapter(child: SectionHeader('Songs')),
              SliverList.builder(
                itemCount: r.songs.length,
                itemBuilder: (context, i) => SongTile(
                  song: r.songs[i],
                  onTap: () {
                    _focus.unfocus();
                    player.playSongs(r.songs, index: i);
                  },
                ),
              ),
            ],
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 190)),
        ],
      ),
    );
  }
}
