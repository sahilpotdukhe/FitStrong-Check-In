import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Who built the app, and how to reach them.
///
/// The owner app carries the same credit under its menu, so the two apps say
/// the same thing. Kept in one place here because it appears both on the sign
/// in screen and behind the "About" button on the scanner.
class Developer {
  const Developer._();

  static const String name = 'Sahil Potdukhe';
  static const String role = 'Design & development';
  static const String site = 'https://sahilpotdukhe.github.io/Portfolio-website/';

  /// What the link reads as on screen - the full address is long enough to
  /// wrap awkwardly on a phone.
  static const String siteLabel = 'sahilpotdukhe.github.io';

  /// Opens the portfolio in the phone's browser.
  ///
  /// Returns false when no browser could take it, so the caller can say so
  /// rather than leaving the tap looking broken.
  static Future<bool> openSite() async {
    try {
      return await launchUrl(
        Uri.parse(site),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      return false;
    }
  }
}

/// The one line credit that sits at the foot of the sign in screen.
///
/// Quiet on purpose: it should be findable, not compete with the sign in box.
class DeveloperCredit extends StatelessWidget {
  const DeveloperCredit({super.key});

  Future<void> _open(BuildContext context) async {
    final opened = await Developer.openSite();
    if (opened || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open the link')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Opacity(
          opacity: 0.75,
          // The white version of the developer's mark, so it reads on the
          // dark background.
          child: Image.asset('assets/brandbg.png', height: 56),
        ),
        Text(
          'Developed by ${Developer.name}',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.72),
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 6),
        TextButton(
          onPressed: () => _open(context),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            foregroundColor: const Color(0xFF34D399),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.open_in_new_rounded, size: 13),
              SizedBox(width: 6),
              // Flexible so a narrow phone, or a large system font, shortens
              // the address rather than running it off the edge.
              Flexible(
                child: Text(
                  Developer.siteLabel,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The same details as a dialog, for the "About" button on the scanner.
Future<void> showDeveloperSheet(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: const Color(0xFF111A14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      title: const Text(
        'FitStrong Attendance',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 20,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Front desk check-in for FitStrong gyms.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 18),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 18),
          Text(
            Developer.role.toUpperCase(),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            Developer.name,
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Close', style: TextStyle(color: Colors.white70)),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF22C55E),
            foregroundColor: Colors.black,
          ),
          onPressed: () async {
            // Held on to before the dialog closes, so the message still has
            // somewhere to go if the link cannot be opened.
            final messenger = ScaffoldMessenger.of(dialogContext);
            Navigator.pop(dialogContext);
            if (await Developer.openSite()) return;
            messenger.showSnackBar(
              const SnackBar(content: Text('Could not open the link')),
            );
          },
          icon: const Icon(Icons.open_in_new_rounded, size: 16),
          label: const Text('Portfolio'),
        ),
      ],
    ),
  );
}
