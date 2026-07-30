import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/steam_app_details.dart';
import '../theme/app_theme.dart';

Future<void> openScreenshotGallery(
  BuildContext context, {
  required List<SteamScreenshot> screenshots,
  required int initialIndex,
}) {
  return Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black87,
      pageBuilder: (_, _, _) => ScreenshotGalleryPage(
        screenshots: screenshots,
        initialIndex: initialIndex,
      ),
      transitionsBuilder: (_, animation, _, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    ),
  );
}

class ScreenshotGalleryPage extends StatefulWidget {
  const ScreenshotGalleryPage({
    super.key,
    required this.screenshots,
    required this.initialIndex,
  });

  final List<SteamScreenshot> screenshots;
  final int initialIndex;

  @override
  State<ScreenshotGalleryPage> createState() => _ScreenshotGalleryPageState();
}

class _ScreenshotGalleryPageState extends State<ScreenshotGalleryPage> {
  late final PageController _pageController;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.screenshots.length - 1);
    _pageController = PageController(initialPage: _index);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.screenshots.length;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: total,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, index) {
              final shot = widget.screenshots[index];
              return InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Center(
                  child: CachedNetworkImage(
                    imageUrl: shot.fullUrl,
                    fit: BoxFit.contain,
                    fadeInDuration: Duration.zero,
                    placeholder: (_, _) => CachedNetworkImage(
                      imageUrl: shot.thumbnailUrl,
                      fit: BoxFit.contain,
                      fadeInDuration: Duration.zero,
                    ),
                    errorWidget: (_, _, _) => const Icon(
                      Icons.broken_image_outlined,
                      color: AppTheme.steamMuted,
                      size: 48,
                    ),
                  ),
                ),
              );
            },
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  Material(
                    color: Colors.black54,
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: IconButton(
                      tooltip: MaterialLocalizations.of(context)
                          .closeButtonTooltip,
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ),
                  const Spacer(),
                  if (total > 1)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '${_index + 1} / $total',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
