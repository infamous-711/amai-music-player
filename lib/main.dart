import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'providers.dart';
import 'audio.dart';
import 'package:rinf/rinf.dart';
import 'dart:ui';

const seedColor = Colors.cyan;

Future<void> main() async {
  // Wait for rust initialization to be completed first
  await Rinf.ensureInitialized();

  // run the flutter app
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  MyAppState createState() => MyAppState();

}

class MyAppState extends ConsumerState<MyApp> {
  final _appLifecycleListener = AppLifecycleListener(
    onExitRequested: () async {
      // Terminate Rust tasks before closing the Flutter app.
      await Rinf.ensureFinalized();
      return AppExitResponse.exit;
    },
  );

  @override
  void dispose() {
    _appLifecycleListener.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const MusicHome(),
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: seedColor),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
            seedColor: seedColor, brightness: Brightness.dark),
      ),
      themeMode: ref.watch(themeModeProvider),
    );
  }
}

class MusicHome extends ConsumerWidget {
  const MusicHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Amai Music Player"),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                const SearchMusicBar(),
                IconButton(
                  icon: Icon(ref.watch(themeModeIconProvider)),
                  onPressed: () => ref.read(themeModeProvider.notifier).update(
                      (theme) => theme == ThemeMode.dark
                          ? ThemeMode.light
                          : ThemeMode.dark),
                  tooltip: "Toggle theme",
                ),
              ],
            ),
          ),
        ],
      ),
      body: const Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(10),
                    child: MusicList(),
                  ),
                ),
                MetadataColumn(),
              ],
            ),
          ),
          MusicControls(),
        ],
      ),
    );
  }
}

class MetadataColumn extends StatelessWidget {
  const MetadataColumn({super.key});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child:
          const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        TrackArt(),
        SizedBox(height: 50.0),
        MusicName(),
      ]),
    );
  }
}

class TrackArt extends ConsumerWidget {
  const TrackArt({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metadata = ref.watch(metadataProvider);

    return metadata.when(
      data: (value) => ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 300,
          maxHeight: 300,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16.0),
          child: Image.memory(value.art),
        ),
      ),
      error: (error, _) => Text("Error: $error"),
      loading: () => const CircularProgressIndicator(),
    );
  }
}

class SearchMusicBar extends ConsumerWidget {
  const SearchMusicBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SearchBar(
      hintText: "Search Music",
      onChanged: (value) =>
          ref.read(searchInputProvider.notifier).state = value,
      leading: const Icon(Icons.search),
    );
  }
}

class MusicName extends ConsumerWidget {
  const MusicName({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metadata = ref.watch(metadataProvider);
    final name = metadata.when(
      data: (value) => value.title,
      error: (_, __) =>
          path.basenameWithoutExtension(ref.watch(currentTrackProvider)),
      loading: () => "",
    );

    return Padding(
      padding: const EdgeInsets.all(10),
      child: Text(
        name,
        overflow: TextOverflow.fade,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 18.0,
        ),
        maxLines: 5,
        textAlign: TextAlign.center,
      ),
    );
  }
}

class MusicControls extends StatelessWidget {
  const MusicControls({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: const Row(children: [
        PlayPrevious(),
        PlayButton(),
        PlayNext(),
        SizedBox(width: 10),
        MusicProgress(),
        Expanded(child: PositionSlider()),
        RepeatButton(),
        ShuffleButton(),
        VolumeSlider(),
      ]),
    );
  }
}

class RepeatButton extends ConsumerWidget {
  const RepeatButton({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: Icon(ref.watch(repeatIconProvider)),
      onPressed: () =>
          ref.read(repeatMusicProvider.notifier).update((repeat) => !repeat),
      tooltip: "Repeat",
    );
  }
}

class ShuffleButton extends ConsumerWidget {
  const ShuffleButton({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: Icon(ref.watch(shuffleIconProvider)),
      onPressed: () =>
          ref.read(shuffleMusicProvider.notifier).update((shuffle) => !shuffle),
      tooltip: "Shuffle",
    );
  }
}

class PlayButton extends ConsumerWidget {
  const PlayButton({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioPlayer = ref.watch(audioPlayerProvider);
    final isPlaying = ref.watch(isPlayingProvider.notifier);

    bool togglePlay(bool isPlaying) {
      isPlaying ? audioPlayer.pause() : audioPlayer.resume();
      return !isPlaying;
    }

    return IconButton(
      icon: Icon(ref.watch(playButtonIconProvider)),
      onPressed: () => isPlaying.update(togglePlay),
      tooltip: "Play",
    );
  }
}

class PlayNext extends ConsumerWidget {
  const PlayNext({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final musicFiles = ref.watch(musicFilesProvider);
    final currentIndex = ref.watch(indexProvider);

    return IconButton(
      icon: const Icon(Icons.skip_next),
      onPressed: () => musicFiles.whenData((value) {
        if ((value.length - 1) != currentIndex && currentIndex >= 0) {
          playMusic(ref, value, currentIndex + 1);
        }
      }),
      tooltip: "Play Next",
    );
  }
}

class PlayPrevious extends ConsumerWidget {
  const PlayPrevious({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final musicFiles = ref.watch(musicFilesProvider);
    final currentIndex = ref.watch(indexProvider);

    return IconButton(
      icon: const Icon(Icons.skip_previous),
      onPressed: () => musicFiles.whenData((value) {
        if (currentIndex > 0) {
          playMusic(ref, value, currentIndex - 1);
        }
      }),
      tooltip: "Play Previous",
    );
  }
}

class VolumeSlider extends ConsumerWidget {
  const VolumeSlider({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final volume = ref.watch(volumeProvider);

    return Row(children: [
      IconButton(
        icon: Icon(ref.watch(volumeIconProvider)),
        onPressed: () => ref.watch(volumeProvider.notifier).update((state) {
          var newVolume =
              1.0; // if it is mute, restore the volume to its full capacity

          // mute the volume if it is not already
          if (state > 0.0) {
            newVolume = 0.0;
          }

          ref.read(audioPlayerProvider).setVolume(newVolume);
          return newVolume;
        }),
        tooltip: "Mute",
      ),
      Slider(
        value: volume,
        onChanged: (newVolume) =>
            ref.watch(volumeProvider.notifier).update((state) {
          ref.read(audioPlayerProvider).setVolume(newVolume);
          return newVolume;
        }),
        max: 1.0,
        min: 0.0,
        divisions: 20,
        label: "${(volume * 100).round()}",
      ),
    ]);
  }
}

class PositionSlider extends ConsumerWidget {
  const PositionSlider({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioPlayer = ref.watch(audioPlayerProvider);
    final currentPosition = ref.watch(positionProvider);
    final audioDuration = ref.watch(durationProvider);

    return Slider(
      min: 0.0,
      max: audioDuration.inMilliseconds.toDouble(),
      value: currentPosition.inMilliseconds.toDouble(),
      onChanged: (newPosition) {
        final position = Duration(milliseconds: newPosition.toInt());
        audioPlayer.seek(position);
        ref.read(positionProvider.notifier).state = position;
      },
    );
  }
}

class MusicProgress extends ConsumerWidget {
  const MusicProgress({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentPosition = ref.watch(positionProvider);
    final audioDuration = ref.watch(durationProvider);

    String progress;
    String totalDuration;

    // the below trick is taken from: https://flutterigniter.com/how-to-format-duration/
    if (audioDuration.inHours >= 1) {
      // for the duration as HH:mm::ss (if the length of the audio is larger than or equal to an hour)
      progress = currentPosition.toString().split('.').first.padLeft(8, "0");
      totalDuration = audioDuration.toString().split('.').first.padLeft(8, "0");
    } else {
      // format the duration as mm:ss
      progress = currentPosition.toString().substring(2, 7);
      totalDuration = audioDuration.toString().substring(2, 7);
    }

    return Text('$progress/$totalDuration');
  }
}

class MusicList extends ConsumerWidget {
  const MusicList({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final musicFiles = ref.watch(musicFilesProvider);
    final index = ref.watch(indexProvider);

    return musicFiles.when(
      data: (value) => ListView.builder(
        itemCount: value.length,
        itemBuilder: (context, trackIndex) {
          String titleName = path.basenameWithoutExtension(value[trackIndex]);
          return ListTile(
            title: Text(titleName),
            onTap: () => playMusic(ref, value, trackIndex),
            selected: trackIndex == index,
            selectedColor: Theme.of(context).colorScheme.onPrimary,
            selectedTileColor: Theme.of(context).colorScheme.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.0),
            ),
          );
        },
      ),
      error: (error, _) => Text("Error: $error"),
      loading: () => const CircularProgressIndicator(),
    );
  }
}
