import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import '../widgets/reading.dart';

class ReaderScreen extends StatelessWidget {
  const ReaderScreen({super.key, required this.reading, required this.state});

  final Reading reading;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.bg0,
      body: AnimatedBuilder(
        animation: state,
        builder: (context, _) {
          final saved = state.isSaved(reading);
          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 340,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      GrayImage(
                        reading: reading,
                        width: double.infinity,
                        height: 340,
                      ),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0x66000000),
                              Color(0x00000000),
                              Color(0xDD131211),
                            ],
                            stops: [0.0, 0.45, 1.0],
                          ),
                        ),
                      ),
                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _RoundButton(
                                icon: Icons.arrow_back,
                                onTap: () => Navigator.of(context).pop(),
                              ),
                              _RoundButton(
                                icon: saved
                                    ? Icons.bookmark
                                    : Icons.bookmark_border,
                                onTap: () => state.toggleSaved(reading),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 24,
                        right: 24,
                        bottom: 22,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${reading.author.toUpperCase()} · ${reading.minutes} MIN READ',
                              style: AppType.badge.copyWith(
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              reading.title,
                              style: const TextStyle(
                                fontFamily: AppType.serif,
                                fontSize: 38,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                                height: 1.02,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 26, 24, 60),
                  child: Text(
                    reading.body,
                    style: const TextStyle(
                      fontFamily: AppType.sans,
                      fontSize: 17,
                      height: 1.62,
                      color: Palette.textHi,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.32),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, size: 20, color: Colors.white),
        ),
      ),
    );
  }
}
