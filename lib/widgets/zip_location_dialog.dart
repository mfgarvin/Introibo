import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../main.dart' show kPrimaryColor, primaryAccentFor;
import '../models/parish.dart';
import '../services/location_service.dart';

/// Asks for a ZIP code and resolves it against the parish data we already
/// carry. Returns the resolved fix, or null if the user cancelled.
///
/// This is the way in for anyone the device can't locate: permission denied,
/// location services off, or no fix available at all. Resolution is entirely
/// local — see [LocationService.centroidForZip].
Future<LocationFix?> showZipLocationDialog(
  BuildContext context,
  List<Parish> parishes,
) {
  return showDialog<LocationFix>(
    context: context,
    builder: (context) => _ZipLocationDialog(parishes: parishes),
  );
}

class _ZipLocationDialog extends StatefulWidget {
  final List<Parish> parishes;

  const _ZipLocationDialog({required this.parishes});

  @override
  State<_ZipLocationDialog> createState() => _ZipLocationDialogState();
}

class _ZipLocationDialogState extends State<_ZipLocationDialog> {
  final TextEditingController _controller = TextEditingController();
  String? _error;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _controller.text = locationService.manualZip ?? '';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final raw = _controller.text.trim();
    if (LocationService.normalizeZip(raw) == null) {
      setState(() => _error = 'Enter a five-digit ZIP code.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final fix = await locationService.setManualZip(raw, widget.parishes);
    if (!mounted) return;

    if (fix == null) {
      setState(() {
        _submitting = false;
        _error = 'No parishes found in that ZIP code. '
            'This app covers the Diocese of Cleveland.';
      });
      return;
    }
    Navigator.of(context).pop(fix);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = primaryAccentFor(isDark: isDark);

    return AlertDialog(
      title: Text(
        'Enter a ZIP code',
        style: GoogleFonts.cormorantGaramond(
          fontSize: 24,
          fontWeight: FontWeight.w600,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "We'll show parishes near that ZIP code instead of your "
            'location. Nothing leaves your device.',
            style: GoogleFonts.inter(fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(5),
            ],
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submitting ? null : _submit(),
            style: GoogleFonts.inter(fontSize: 16),
            decoration: InputDecoration(
              // Faint on purpose: at full opacity the sample ZIP reads as a
              // value already in the field rather than as a prompt.
              hintText: '44107',
              hintStyle: GoogleFonts.inter(
                fontSize: 16,
                color: (isDark ? Colors.white : Colors.black)
                    .withValues(alpha: 0.35),
              ),
              errorText: _error,
              border: const OutlineInputBorder(),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: accent, width: 2),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: GoogleFonts.inter(color: Colors.grey.shade600),
          ),
        ),
        ElevatedButton(
          onPressed: _submitting ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: kPrimaryColor,
            foregroundColor: Colors.white,
          ),
          child: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  'Use this ZIP',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
        ),
      ],
    );
  }
}
