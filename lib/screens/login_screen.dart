import 'package:flutter/material.dart';

import '../auth.dart';
import '../theme.dart';

const List<double> _grayscale = <double>[
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0, 0, 0, 1, 0, //
];

class _Social {
  const _Social(this.provider, this.icon, {this.glyph});
  final String provider;
  final IconData? icon;
  final String? glyph;
}

const List<_Social> _socials = [
  _Social('Apple', Icons.apple),
  _Social('Facebook', Icons.facebook),
  _Social('X', null, glyph: '𝕏'),
  _Social('Instagram', Icons.camera_alt_outlined),
];

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key, required this.auth});

  final AuthController auth;

  Future<void> _handleSheet(BuildContext context, String provider) async {
    final controller = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Palette.bg1,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 22,
            right: 22,
            top: 22,
            bottom: 22 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Continue with $provider',
                style: const TextStyle(
                  fontFamily: AppType.serif,
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                  color: Palette.textHi,
                ),
              ),
              const SizedBox(height: 6),
              Text('Enter your $provider handle to continue.',
                  style: AppType.cardBody),
              const SizedBox(height: 18),
              TextField(
                controller: controller,
                autofocus: true,
                style: const TextStyle(color: Palette.textHi, fontSize: 16),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => Navigator.of(ctx).pop(),
                decoration: InputDecoration(
                  prefixText: '@ ',
                  prefixStyle: TextStyle(color: Palette.textMid, fontSize: 16),
                  hintText: 'yourhandle',
                  hintStyle: TextStyle(color: Palette.textLow),
                  filled: true,
                  fillColor: Palette.surface,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Palette.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Palette.borderStrong),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Palette.textHi,
                    foregroundColor: Palette.bg0,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    final v = controller.text.trim();
                    if (v.isEmpty) return;
                    Navigator.of(ctx).pop();
                    auth.signInWithHandle(provider, v);
                  },
                  child: const Text('Continue',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        );
      },
    );
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.bg0,
      body: Stack(
        fit: StackFit.expand,
        children: [
          ColorFiltered(
            colorFilter: const ColorFilter.matrix(_grayscale),
            child: Image.asset(
              'assets/images/hero.jpg',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              errorBuilder: (_, _, _) => Container(color: Palette.bg1),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x99131211),
                  Color(0x44131211),
                  Color(0xF2131211),
                ],
                stops: [0.0, 0.4, 0.92],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 28, 28, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(flex: 3),
                  Text('séance',
                      style: AppType.logo.copyWith(fontSize: 52)),
                  const SizedBox(height: 14),
                  Text(
                    'A quiet practice for a steadier center.',
                    style: TextStyle(
                      fontFamily: AppType.sans,
                      fontSize: 16,
                      height: 1.4,
                      color: Colors.white.withValues(alpha: 0.78),
                    ),
                  ),
                  const Spacer(flex: 4),
                  AnimatedBuilder(
                    animation: auth,
                    builder: (context, _) => _GoogleButton(
                      busy: auth.busy,
                      onTap: auth.busy ? null : auth.signInWithGoogle,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(child: Divider(color: Palette.border)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('or use a social handle',
                            style: AppType.badge),
                      ),
                      Expanded(child: Divider(color: Palette.border)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final s in _socials) ...[
                        _SocialButton(
                          social: s,
                          onTap: () => _handleSheet(context, s.provider),
                        ),
                        if (s != _socials.last) const SizedBox(width: 16),
                      ],
                    ],
                  ),
                  const SizedBox(height: 26),
                  Center(
                    child: Text(
                      'By continuing you agree to the Practice & Privacy terms.',
                      textAlign: TextAlign.center,
                      style: AppType.badge.copyWith(letterSpacing: 0.3),
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

class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        onPressed: onTap,
        child: busy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Color(0xFF1A1A1A),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  _GoogleGlyph(),
                  SizedBox(width: 12),
                  Text(
                    'Continue with Google',
                    style: TextStyle(
                      fontFamily: AppType.sans,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _GoogleGlyph extends StatelessWidget {
  const _GoogleGlyph();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 20,
      height: 20,
      child: Text(
        'G',
        style: TextStyle(
          fontFamily: AppType.sans,
          fontSize: 19,
          fontWeight: FontWeight.w700,
          color: Color(0xFF4285F4),
          height: 1.0,
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({required this.social, required this.onTap});

  final _Social social;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.08),
      shape: CircleBorder(
        side: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 56,
          height: 56,
          child: Center(
            child: social.icon != null
                ? Icon(social.icon, size: 24, color: Colors.white)
                : Text(
                    social.glyph!,
                    style: const TextStyle(
                      fontSize: 22,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
