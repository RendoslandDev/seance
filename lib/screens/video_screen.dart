import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../models.dart';
import '../theme.dart';
import '../widgets/bible.dart' show timeAgo;

/// Plays one video in-app (YouTube's embedded player, privacy-enhanced mode).
class VideoScreen extends StatefulWidget {
  const VideoScreen({super.key, required this.video});

  final Video video;

  @override
  State<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> {
  late final YoutubePlayerController _controller =
      YoutubePlayerController.fromVideoId(
        videoId: widget.video.id,
        autoPlay: true,
        params: const YoutubePlayerParams(
          showFullscreenButton: true,
          strictRelatedVideos: true,
        ),
      );

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.video;
    return Scaffold(
      backgroundColor: Palette.bg0,
      appBar: AppBar(
        backgroundColor: Palette.bg0,
        foregroundColor: Palette.textHi,
        elevation: 0,
        title: Text(
          v.channel,
          style: const TextStyle(fontFamily: AppType.sans, fontSize: 16),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: YoutubePlayer(controller: _controller),
              ),
              const SizedBox(height: 18),
              Text(
                v.title,
                style: const TextStyle(
                  fontFamily: AppType.serif,
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                  height: 1.25,
                  color: Palette.textHi,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${v.channel.toUpperCase()} · '
                '${timeAgo(v.published, DateTime.now()).toUpperCase()}',
                style: AppType.badge,
              ),
              if (v.description.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(v.description, style: AppType.cardBody),
              ],
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () => launchUrl(
                    v.watchUrl,
                    mode: LaunchMode.externalApplication,
                  ),
                  icon: const Icon(Icons.open_in_new, size: 17),
                  label: const Text('Open in YouTube'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Palette.textHi,
                    side: BorderSide(color: Palette.borderStrong),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
