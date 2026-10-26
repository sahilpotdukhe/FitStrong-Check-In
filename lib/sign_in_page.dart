import 'dart:ui' as ui;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'developer_credit.dart';

/// The brand green, and the lighter tint the gradients run to.
const Color _green = Color(0xFF22C55E);
const Color _greenLight = Color(0xFF4ADE80);

/// Signs the tablet in as the gym, once.
///
/// Firebase keeps the session on the device afterwards, so the desk never
/// sees this screen again unless somebody signs out.
class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  /// Where the desk's email is kept between sign ins.
  static const String _rememberKey = 'remember_email';
  static const String _emailKey = 'desk_email';

  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _hidden = true;

  /// Whether to put the email back in the box next time.
  ///
  /// It is not about staying signed in - Firebase already keeps the session
  /// on the device. It only saves the desk retyping the gym address if
  /// somebody signs out and back in.
  bool _remember = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _restoreEmail();
  }

  Future<void> _restoreEmail() async {
    try {
      final store = await SharedPreferences.getInstance();
      final remember = store.getBool(_rememberKey) ?? true;
      final saved = store.getString(_emailKey) ?? '';
      if (!mounted) return;
      setState(() {
        _remember = remember;
        if (remember && saved.isNotEmpty) _email.text = saved;
      });
    } catch (_) {
      // A device that will not give us storage is no reason to block sign in;
      // the box simply starts empty.
    }
  }

  Future<void> _saveEmail() async {
    try {
      final store = await SharedPreferences.getInstance();
      await store.setBool(_rememberKey, _remember);
      if (_remember) {
        await store.setString(_emailKey, _email.text.trim());
      } else {
        await store.remove(_emailKey);
      }
    } catch (_) {
      // Nothing to tell the user: the sign in itself still worked.
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate() || _busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
      await _saveEmail();
      // The gate in main.dart notices the sign in and swaps the screen.
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _messageFor(e.code));
    } catch (_) {
      setState(() => _error = 'Could not sign in. Check the connection.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Firebase returns the same code for a wrong email and a wrong password on
  /// purpose, so the message stays vague in the same way.
  String _messageFor(String code) {
    switch (code) {
      case 'invalid-email':
        return 'That does not look like an email address.';
      case 'network-request-failed':
        return 'No connection. Check the gym Wi-Fi.';
      case 'too-many-requests':
        return 'Too many attempts. Wait a minute and try again.';
      default:
        return 'Email or password is incorrect.';
    }
  }

  /// Sends a reset link to whichever address the desk types.
  Future<void> _forgotPassword() async {
    final controller = TextEditingController(text: _email.text.trim());
    final address = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF111A14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Reset password',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'We will email a link to set a new password.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Gym email',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _green),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white70)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _green,
              foregroundColor: Colors.black,
            ),
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Send link'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (address == null || address.isEmpty || !mounted) return;

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: address);
      if (!mounted) return;
      // Firebase deliberately does not say whether the address has an
      // account, so neither do we.
      _toast('If that email has an account, a reset link is on its way.');
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      _toast(e.code == 'invalid-email'
          ? 'That does not look like an email address.'
          : 'Could not send the link. Check the connection.');
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF1B2A20),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The keyboard must not squash the layout - the form scrolls instead.
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFF07100B),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // A dim gym photo, the same one the owner app uses, so the two
          // apps feel like one product. Blurred because the logo sits over
          // it: out of focus it reads as texture instead of competing with
          // the mark. Clamped so the blur does not fade out at the edges.
          ImageFiltered(
            imageFilter: ui.ImageFilter.blur(
              sigmaX: 7,
              sigmaY: 7,
              tileMode: TileMode.clamp,
            ),
            child: Image.asset('assets/gymbg.jpg', fit: BoxFit.cover),
          ),
          // Darkened on a slope: enough of the gym shows through at the top
          // to set the mood, and it goes almost solid lower down so the form
          // never has to compete with the picture behind it.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.42, 1.0],
                colors: [
                  Color(0xAA060D08),
                  Color(0xD90A1410),
                  Color(0xF7050B07),
                ],
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const _BrandHeader(),
                      const SizedBox(height: 26),
                      const _FeatureStrip(),
                      const SizedBox(height: 30),
                      _signInCard(),
                      const SizedBox(height: 26),
                      const DeveloperCredit(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The dark glass panel holding the form.
  Widget _signInCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1710).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 30, offset: Offset(0, 12)),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Sign In',
              style: TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.w800,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Welcome back!',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.78),
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Log in to manage your gym and track attendance.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.52),
                fontSize: 13.5,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 22),
            _field(
              controller: _email,
              hint: 'Email',
              icon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Enter the gym email'
                  : null,
            ),
            const SizedBox(height: 14),
            _field(
              controller: _password,
              hint: 'Password',
              icon: Icons.lock_outline_rounded,
              obscure: _hidden,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _signIn(),
              suffix: IconButton(
                icon: Icon(
                  _hidden
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: Colors.white.withValues(alpha: 0.45),
                  size: 21,
                ),
                tooltip: _hidden ? 'Show password' : 'Hide password',
                onPressed: () => setState(() => _hidden = !_hidden),
              ),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Enter the password' : null,
            ),
            const SizedBox(height: 10),
            _rememberRow(),
            if (_error != null) ...[
              const SizedBox(height: 14),
              _errorBanner(_error!),
            ],
            const SizedBox(height: 18),
            _submitButton(),
          ],
        ),
      ),
    );
  }

  /// One dark, rounded input. Built by hand so both boxes match the design
  /// exactly rather than inheriting Material's lighter styling.
  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    void Function(String)? onSubmitted,
    Widget? suffix,
    bool obscure = false,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onFieldSubmitted: onSubmitted,
      autocorrect: false,
      enableSuggestions: false,
      style: const TextStyle(color: Colors.white, fontSize: 15.5),
      cursorColor: _green,
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.42),
          fontSize: 15.5,
        ),
        prefixIcon: Icon(
          icon,
          color: Colors.white.withValues(alpha: 0.45),
          size: 21,
        ),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        contentPadding: const EdgeInsets.symmetric(vertical: 18),
        enabledBorder: _border(Colors.white.withValues(alpha: 0.12)),
        focusedBorder: _border(_green.withValues(alpha: 0.75), width: 1.4),
        errorBorder: _border(const Color(0xFFF87171)),
        focusedErrorBorder: _border(const Color(0xFFF87171), width: 1.4),
        errorStyle: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 12.5),
      ),
    );
  }

  OutlineInputBorder _border(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  /// "Remember me" on the left, "Forgot Password?" on the right.
  ///
  /// A Wrap rather than a Row: on a narrow phone, or when the reader has
  /// turned the system font size up, the two will not share a line, and this
  /// drops the link onto its own line instead of clipping it.
  Widget _rememberRow() {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 4,
      children: [
        _rememberToggle(),
        TextButton(
          onPressed: _busy ? null : _forgotPassword,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            foregroundColor: _greenLight,
          ),
          child: const Text(
            'Forgot Password?',
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  Widget _rememberToggle() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 26,
          width: 26,
          child: Checkbox(
            value: _remember,
            onChanged: (v) => setState(() => _remember = v ?? false),
            activeColor: _green,
            checkColor: Colors.black,
            side: BorderSide(
              color: Colors.white.withValues(alpha: 0.35),
              width: 1.6,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Tapping the words works too - the box alone is a small target.
        GestureDetector(
          onTap: () => setState(() => _remember = !_remember),
          child: Text(
            'Remember me',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _errorBanner(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF87171).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFF87171).withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 19, color: Color(0xFFFCA5A5)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFFFCA5A5),
                fontSize: 13.5,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The green pill at the bottom of the card.
  Widget _submitButton() {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: LinearGradient(
          colors: _busy
              ? [
                  _greenLight.withValues(alpha: 0.5),
                  _green.withValues(alpha: 0.5),
                ]
              : const [_greenLight, _green],
        ),
        boxShadow: _busy
            ? null
            : [
                BoxShadow(
                  color: _green.withValues(alpha: 0.35),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: _busy ? null : _signIn,
          child: Container(
            height: 58,
            alignment: Alignment.center,
            child: _busy
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.black87,
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Sign In',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(width: 10),
                      Icon(Icons.arrow_forward_rounded,
                          color: Colors.black, size: 21),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// The logo, the wordmark and the tagline.
class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset('assets/logo_mark.png', height: 86),
        const SizedBox(height: 14),
        // "Fit" in white, "Strong" in green, as one word.
        const Text.rich(
          TextSpan(
            children: [
              TextSpan(text: 'Fit', style: TextStyle(color: Colors.white)),
              TextSpan(text: 'Strong', style: TextStyle(color: _green)),
            ],
          ),
          style: TextStyle(
            fontSize: 44,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            height: 1.05,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'ATTENDANCE',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.82),
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 7,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Simple. Secure. Always On.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.62),
            fontSize: 14.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// The three things the app does, as icons across the screen.
class _FeatureStrip extends StatelessWidget {
  const _FeatureStrip();

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Expanded(
            child: _Feature(
              icon: Icons.qr_code_scanner_rounded,
              label: 'Scan\nCheck-ins',
            ),
          ),
          _divider(),
          const Expanded(
            child: _Feature(
              icon: Icons.groups_rounded,
              label: 'Manage\nMembers',
            ),
          ),
          _divider(),
          const Expanded(
            child: _Feature(
              icon: Icons.bar_chart_rounded,
              label: 'Track\nAttendance',
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(
        width: 1,
        margin: const EdgeInsets.symmetric(vertical: 6),
        color: Colors.white.withValues(alpha: 0.14),
      );
}

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 46,
          width: 46,
          decoration: BoxDecoration(
            color: _green.withValues(alpha: 0.16),
            shape: BoxShape.circle,
            border: Border.all(color: _green.withValues(alpha: 0.28)),
          ),
          child: Icon(icon, color: _greenLight, size: 23),
        ),
        const SizedBox(height: 9),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.86),
            fontSize: 12.5,
            height: 1.25,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
