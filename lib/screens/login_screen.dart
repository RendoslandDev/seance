import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth.dart';
import '../theme.dart';
import 'legal_screen.dart';

const List<double> _grayscale = <double>[
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0, 0, 0, 1, 0, //
];

class _Country {
  const _Country(this.flag, this.name, this.dialCode);
  final String flag;
  final String name;
  final String dialCode;
}

/// Ghana first; anyone else can pick their country or type a full +number.
const List<_Country> _countries = [
  _Country('🇬🇭', 'Ghana', '+233'),
  _Country('🇳🇬', 'Nigeria', '+234'),
  _Country('🇨🇮', 'Côte d’Ivoire', '+225'),
  _Country('🇹🇬', 'Togo', '+228'),
  _Country('🇧🇫', 'Burkina Faso', '+226'),
  _Country('🇧🇯', 'Benin', '+229'),
  _Country('🇸🇱', 'Sierra Leone', '+232'),
  _Country('🇱🇷', 'Liberia', '+231'),
  _Country('🇰🇪', 'Kenya', '+254'),
  _Country('🇺🇬', 'Uganda', '+256'),
  _Country('🇿🇦', 'South Africa', '+27'),
  _Country('🇬🇧', 'United Kingdom', '+44'),
  _Country('🇺🇸', 'United States / Canada', '+1'),
  _Country('🇩🇪', 'Germany', '+49'),
  _Country('🇳🇱', 'Netherlands', '+31'),
  _Country('🇮🇹', 'Italy', '+39'),
];

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key, required this.auth});

  final AuthController auth;

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
            // Scrolls when the keyboard is up; fills the screen otherwise.
            child: LayoutBuilder(
              builder: (context, c) => SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: c.maxHeight - 56),
                  child: IntrinsicHeight(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Spacer(flex: 3),
                            Text(
                              'séance',
                              style: AppType.logo.copyWith(fontSize: 52),
                            ),
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
                            if (AuthController.cloudEnabled)
                              _PhoneSignIn(auth: auth)
                            else
                              _PrimaryButton(
                                label: 'Begin',
                                onTap: auth.continueOnDevice,
                              ),
                            const SizedBox(height: 22),
                            Center(
                              child: Text(
                                AuthController.cloudEnabled
                                    ? 'New here? Your account is created when '
                                          'you confirm your number.'
                                    : 'Development build · your practice is '
                                          'saved on this device.',
                                textAlign: TextAlign.center,
                                style: AppType.badge.copyWith(
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            const _Consent(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sign in or sign up with a phone number: enter the number, then the
/// 6-digit code texted to it.
class _PhoneSignIn extends StatefulWidget {
  const _PhoneSignIn({required this.auth});
  final AuthController auth;

  @override
  State<_PhoneSignIn> createState() => _PhoneSignInState();
}

class _PhoneSignInState extends State<_PhoneSignIn> {
  final _number = TextEditingController();
  final _code = TextEditingController();
  _Country _country = _countries.first;
  String? _localError;
  Timer? _tick;

  AuthController get _auth => widget.auth;

  @override
  void initState() {
    super.initState();
    // Re-render each second for the resend countdown.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _auth.awaitingCode) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _number.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final phone = normalizePhone(_number.text, _country.dialCode);
    if (phone == null) {
      setState(() => _localError = 'Enter your full phone number.');
      return;
    }
    setState(() => _localError = null);
    _code.clear();
    await _auth.sendCode(phone);
  }

  Future<void> _resend() async {
    final phone = _auth.pendingPhone;
    if (phone == null) return;
    _code.clear();
    await _auth.sendCode(phone, resend: true);
  }

  Future<void> _verify() async {
    if (_code.text.length != 6 || _auth.busy) return;
    await _auth.verifyCode(_code.text);
  }

  InputDecoration _field(String hint, {Widget? prefix}) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
    prefixIcon: prefix,
    filled: true,
    fillColor: Colors.white.withValues(alpha: 0.08),
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _auth,
      builder: (context, _) {
        final error = _localError ?? _auth.error;
        return AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!_auth.awaitingCode) ..._numberStep() else ..._codeStep(),
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(
                  error,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFE8A598),
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  List<Widget> _numberStep() => [
    Text('Your phone number', style: _labelStyle),
    const SizedBox(height: 10),
    TextField(
      controller: _number,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.go,
      autofillHints: const [AutofillHints.telephoneNumberNational],
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[\d +()-]')),
      ],
      onSubmitted: (_) => _send(),
      style: const TextStyle(color: Colors.white, fontSize: 18),
      decoration: _field(
        '24 123 4567',
        prefix: _CountryButton(
          country: _country,
          onChanged: (c) => setState(() => _country = c),
        ),
      ),
    ),
    const SizedBox(height: 14),
    _PrimaryButton(
      label: 'Send code',
      busy: _auth.busy,
      onTap: _auth.busy ? null : _send,
    ),
    const SizedBox(height: 10),
    Text(
      'We’ll text you a 6-digit code. Standard SMS rates may apply.',
      textAlign: TextAlign.center,
      style: AppType.badge.copyWith(letterSpacing: 0.2),
    ),
  ];

  List<Widget> _codeStep() {
    final sentAt = _auth.codeSentAt ?? DateTime.now();
    final wait = AuthController.resendAfter - DateTime.now().difference(sentAt);
    final canResend = wait <= Duration.zero && !_auth.busy;
    return [
      Text('Enter the code', style: _labelStyle),
      const SizedBox(height: 4),
      Text(
        'Sent by SMS to ${_auth.pendingPhone}',
        style: TextStyle(
          fontFamily: AppType.sans,
          fontSize: 14,
          color: Colors.white.withValues(alpha: 0.7),
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _code,
        autofocus: true,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 6,
        autofillHints: const [AutofillHints.oneTimeCode],
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (v) {
          if (v.length == 6) _verify();
        },
        onSubmitted: (_) => _verify(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 26,
          letterSpacing: 12,
          fontWeight: FontWeight.w600,
        ),
        decoration: _field('••••••').copyWith(counterText: ''),
      ),
      const SizedBox(height: 14),
      _PrimaryButton(
        label: 'Verify',
        busy: _auth.busy,
        onTap: _auth.busy ? null : _verify,
      ),
      const SizedBox(height: 6),
      Row(
        children: [
          TextButton(
            onPressed: _auth.busy ? null : _auth.changeNumber,
            style: _linkStyle,
            child: const Text('Change number'),
          ),
          const Spacer(),
          TextButton(
            onPressed: canResend ? _resend : null,
            style: _linkStyle,
            child: Text(
              canResend
                  ? 'Resend code'
                  : 'Resend in 0:${wait.inSeconds.clamp(0, 59).toString().padLeft(2, '0')}',
            ),
          ),
        ],
      ),
    ];
  }

  static const _labelStyle = TextStyle(
    fontFamily: AppType.serif,
    fontSize: 22,
    fontWeight: FontWeight.w500,
    color: Colors.white,
  );

  static final _linkStyle = TextButton.styleFrom(
    foregroundColor: Colors.white.withValues(alpha: 0.85),
    disabledForegroundColor: Colors.white.withValues(alpha: 0.4),
    textStyle: const TextStyle(fontFamily: AppType.sans, fontSize: 14),
  );
}

class _CountryButton extends StatelessWidget {
  const _CountryButton({required this.country, required this.onChanged});
  final _Country country;
  final ValueChanged<_Country> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_Country>(
      tooltip: 'Country code',
      color: Palette.bg1,
      initialValue: country,
      onSelected: onChanged,
      itemBuilder: (_) => [
        for (final c in _countries)
          PopupMenuItem(
            value: c,
            child: Text(
              '${c.flag}  ${c.name}  ${c.dialCode}',
              style: const TextStyle(color: Palette.textHi),
            ),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.only(left: 14, right: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(country.flag, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 6),
            Text(
              country.dialCode,
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
            Icon(
              Icons.arrow_drop_down,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, this.onTap, this.busy = false});

  final String label;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1A1A1A),
          disabledBackgroundColor: Colors.white.withValues(alpha: 0.6),
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
            : Text(
                label,
                style: const TextStyle(
                  fontFamily: AppType.sans,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}

/// "By continuing you agree to the Terms of Service and Privacy Policy."
class _Consent extends StatefulWidget {
  const _Consent();

  @override
  State<_Consent> createState() => _ConsentState();
}

class _ConsentState extends State<_Consent> {
  late final _terms = TapGestureRecognizer()
    ..onTap = () => openLegal(context, LegalDoc.terms);
  late final _privacy = TapGestureRecognizer()
    ..onTap = () => openLegal(context, LegalDoc.privacy);

  @override
  void dispose() {
    _terms.dispose();
    _privacy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final link = TextStyle(
      color: Colors.white.withValues(alpha: 0.9),
      decoration: TextDecoration.underline,
    );
    return Text.rich(
      TextSpan(
        children: [
          const TextSpan(text: 'By continuing you agree to the '),
          TextSpan(text: 'Terms of Service', style: link, recognizer: _terms),
          const TextSpan(text: ' and '),
          TextSpan(text: 'Privacy Policy', style: link, recognizer: _privacy),
          const TextSpan(text: '.'),
        ],
      ),
      textAlign: TextAlign.center,
      style: TextStyle(
        fontFamily: AppType.sans,
        fontSize: 12.5,
        height: 1.5,
        color: Colors.white.withValues(alpha: 0.6),
      ),
    );
  }
}
