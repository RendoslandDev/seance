import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth.dart';
import '../models.dart';
import '../theme.dart';

const _danger = Color(0xFFE8A598);

/// Profile → Delete account. Erases the member's progress, bookmarks and
/// journal, then the account itself (required by the App Store and Play Store
/// for apps that let people create accounts).
Future<void> deleteAccountFlow(
  BuildContext context,
  AuthController auth,
  AppState state,
) async {
  final user = auth.user;
  if (user == null) return;
  final messenger = ScaffoldMessenger.of(context);

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Palette.bg1,
      title: const Text(
        'Delete your account?',
        style: TextStyle(fontFamily: AppType.serif, color: Palette.textHi),
      ),
      content: Text(
        user.isGuest
            ? 'This permanently erases your progress, bookmarks and journal '
                  'from this device.'
            : 'This permanently erases your progress, bookmarks and journal '
                  'entries, and removes your account for ${user.phone ?? 'this number'}. '
                  'It can’t be undone.',
        style: AppType.cardBody,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text('Cancel', style: TextStyle(color: Palette.textMid)),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Delete', style: TextStyle(color: _danger)),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  void say(String text) => messenger
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Palette.bg1,
        content: Text(text, style: const TextStyle(color: Palette.textHi)),
      ),
    );

  try {
    // Data first: once the account is gone, the database no longer lets us
    // remove what it held.
    await state.deleteAllData();
    if (await auth.deleteSignedInAccount()) {
      say('Your account and data have been deleted.');
      return;
    }
  } catch (e) {
    say('Couldn’t delete your account. Check your connection and try again.');
    return;
  }

  // Firebase wants a recent sign-in before removing the account.
  if (!context.mounted) return;
  final done = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Palette.bg1,
    isScrollControlled: true,
    isDismissible: false,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (_) => _ConfirmNumberSheet(auth: auth, phone: user.phone ?? ''),
  );
  if (done == true) {
    say('Your account and data have been deleted.');
  } else {
    // Data is already erased; don't leave a half-deleted session open.
    await auth.signOut();
    say(
      'Your data was deleted. Sign in again to finish removing your account.',
    );
  }
}

/// Re-confirms the member's number with a fresh SMS code, then deletes the
/// account. Pops true when the account is gone.
class _ConfirmNumberSheet extends StatefulWidget {
  const _ConfirmNumberSheet({required this.auth, required this.phone});
  final AuthController auth;
  final String phone;

  @override
  State<_ConfirmNumberSheet> createState() => _ConfirmNumberSheetState();
}

class _ConfirmNumberSheetState extends State<_ConfirmNumberSheet> {
  final _code = TextEditingController();

  AuthController get _auth => widget.auth;

  @override
  void initState() {
    super.initState();
    _auth.sendCode(widget.phone);
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_code.text.length != 6 || _auth.busy) return;
    await _auth.verifyCode(_code.text);
    if (_auth.error != null || !mounted) return;
    try {
      final deleted = await _auth.deleteSignedInAccount();
      if (mounted && deleted) Navigator.of(context).pop(true);
    } catch (_) {
      // The error is shown from auth.error.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        22,
        22,
        22,
        22 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: AnimatedBuilder(
        animation: _auth,
        builder: (context, _) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Confirm it’s you',
              style: TextStyle(
                fontFamily: AppType.serif,
                fontSize: 24,
                color: Palette.textHi,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _auth.awaitingCode
                  ? 'Enter the code we texted to ${widget.phone} to finish '
                        'deleting your account.'
                  : 'Sending a code to ${widget.phone}…',
              style: AppType.cardBody,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _code,
              autofocus: true,
              enabled: _auth.awaitingCode,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 6,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (v) {
                if (v.length == 6) _verify();
              },
              style: const TextStyle(
                color: Palette.textHi,
                fontSize: 24,
                letterSpacing: 10,
              ),
              decoration: InputDecoration(
                counterText: '',
                hintText: '••••••',
                hintStyle: TextStyle(color: Palette.textLow),
                filled: true,
                fillColor: Palette.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            if (_auth.error != null) ...[
              const SizedBox(height: 10),
              Text(_auth.error!, style: const TextStyle(color: _danger)),
            ],
            const SizedBox(height: 14),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _danger,
                foregroundColor: Palette.bg0,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              onPressed: _auth.busy || !_auth.awaitingCode ? null : _verify,
              child: const Text('Delete my account'),
            ),
            TextButton(
              onPressed: _auth.busy
                  ? null
                  : () => Navigator.of(context).pop(false),
              child: Text('Cancel', style: TextStyle(color: Palette.textMid)),
            ),
          ],
        ),
      ),
    );
  }
}
