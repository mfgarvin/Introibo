import 'package:flutter/material.dart';

import '../models/parish.dart';
import '../theme/app_text.dart';
import '../utils/plan_place.dart';

/// The pieces of a filter written as a sentence — "Show me Mass on Sunday
/// in the afternoon near Akron". Shared by the Home planner and the bar at
/// the top of the filtered lists, so the two read and behave as one control.

const _weekdayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

/// "Sunday" for an ISO weekday (1 = Monday).
String weekdayName(int weekday) => _weekdayNames[weekday - 1];

/// The seven days from [today], today first. Built from fields rather than by
/// adding durations, so a DST change can't land one on the wrong date.
List<DateTime> comingWeek(DateTime today) => [
      for (var i = 0; i < 7; i++)
        DateTime(today.year, today.month, today.day + i),
    ];

/// A day within the coming week, as a menu item: Today, Tomorrow, then plain
/// weekday names. Within a week the name says which day, and a date only
/// makes the sentence harder to read.
String dayChoiceLabel(DateTime day, DateTime today) =>
    switch (DateTime(day.year, day.month, day.day).difference(today).inDays) {
      0 => 'Today',
      1 => 'Tomorrow',
      _ => weekdayName(day.weekday),
    };

/// How a tappable word is set. In the planner's sentence the word is the
/// whole surface, so it is bold and underlined to stand out from the prose
/// around it. In the [compact] bar over a list, every word is a control and
/// the caret already says so: bold *and* underlined on every one was a hard
/// line to read, so it is a size larger, semi-bold, and plain.
TextStyle wordStyle(Color accent, {required bool compact}) => compact
    ? AppText.bodyLarge(color: accent).copyWith(fontWeight: FontWeight.w600)
    : AppText.bodyLarge(color: accent).copyWith(
        fontWeight: FontWeight.w700,
        decoration: TextDecoration.underline,
        decorationColor: accent.withValues(alpha: 0.5),
      );

/// The bubble a [compact] word sits in: a shade darker than the bar
/// behind it, so each control reads as its own thing.
Color wordBubbleColor(Color accent) => accent.withValues(alpha: 0.14);

const _bubbleRadius = BorderRadius.all(Radius.circular(8));

/// A tappable word in a sentence: accent, underlined, with a caret, so it
/// reads as part of the sentence and as something to change. Tapping opens a
/// menu of [values] right where it is.
class MenuWord<T> extends StatelessWidget {
  final String label;
  final List<T> values;
  final String Function(T) itemLabel;
  final void Function(T) onSelected;
  final Color accent;

  /// Smaller words for a bar that sits above a list rather than a sentence
  /// that is the whole surface.
  final bool compact;

  const MenuWord({
    super.key,
    required this.label,
    required this.values,
    required this.itemLabel,
    required this.onSelected,
    required this.accent,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = wordStyle(accent, compact: compact);
    final word = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: style),
        Icon(Icons.arrow_drop_down, color: accent, size: compact ? 18 : 20),
      ],
    );
    return PopupMenuButton<T>(
      tooltip: '',
      onSelected: onSelected,
      itemBuilder: (_) => [
        for (final v in values)
          PopupMenuItem<T>(value: v, child: Text(itemLabel(v))),
      ],
      child: compact
          ? Container(
              padding: const EdgeInsets.fromLTRB(10, 3, 4, 3),
              decoration: BoxDecoration(
                color: wordBubbleColor(accent),
                borderRadius: _bubbleRadius,
              ),
              child: word,
            )
          : word,
    );
  }
}

/// One choice in the place menu. [place] null is "near me".
class _WhereOption {
  final String label;
  final PlanPlace? place;
  const _WhereOption(this.label, this.place);

  @override
  bool operator ==(Object other) =>
      other is _WhereOption && other.label == label && other.place == place;

  @override
  int get hashCode => Object.hash(label, place);
}

/// The place word: a fill-in field. "me" until you type; a city or ZIP
/// offers itself as you go, with "Near me" always the first way back.
///
/// Controlled: [place] is the current answer (null = near me) and
/// [onChanged] reports a new one. Nothing is stored — planning a Saturday in
/// Akron must not become where the app thinks you live.
class PlaceWord extends StatefulWidget {
  final List<Parish> parishes;
  final PlanPlace? place;

  /// Whether "near me" is possible at all; without a fix the word starts
  /// empty and asks for a city or ZIP.
  final bool hasLocation;

  final ValueChanged<PlanPlace?> onChanged;
  final Color accent;
  final Color hintColor;
  final bool compact;
  final double width;

  const PlaceWord({
    super.key,
    required this.parishes,
    required this.place,
    required this.hasLocation,
    required this.onChanged,
    required this.accent,
    required this.hintColor,
    this.compact = false,
    this.width = 160,
  });

  @override
  State<PlaceWord> createState() => _PlaceWordState();
}

class _PlaceWordState extends State<PlaceWord> {
  static const _meLabel = 'me';

  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _showCurrent();
    // Focusing the word selects it, so typing a city replaces "me" outright
    // instead of appending to it; leaving it unresolved puts the current
    // answer back rather than stranding half-typed text.
    _focus.addListener(() {
      if (_focus.hasFocus) {
        _controller.selection =
            TextSelection(baseOffset: 0, extentOffset: _controller.text.length);
      } else {
        _showCurrent();
      }
    });
  }

  @override
  void didUpdateWidget(PlaceWord old) {
    super.didUpdateWidget(old);
    // A new answer from outside, or a fix arriving after the field was
    // built: show it, unless the user is mid-typing.
    if ((old.place != widget.place || old.hasLocation != widget.hasLocation) &&
        !_focus.hasFocus) {
      _showCurrent();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _showCurrent() {
    _controller.text =
        widget.place?.label ?? (widget.hasLocation ? _meLabel : '');
  }

  void _choose(_WhereOption option) {
    _focus.unfocus();
    widget.onChanged(option.place);
    _controller.text =
        option.place?.label ?? (widget.hasLocation ? _meLabel : '');
  }

  /// Enter: take what was typed. An exact city or ZIP wins; otherwise the
  /// best city match; otherwise nothing changes and the field shows the
  /// current place again. Not RawAutocomplete's own submit, which takes the
  /// first option — always "Near me" — so Enter after "Akron" went home.
  void _submit(String text) {
    final q = text.trim();
    if (q.isEmpty || q == _meLabel) {
      if (widget.hasLocation) _choose(const _WhereOption('Near me', null));
      return;
    }
    if (q == widget.place?.label) {
      _focus.unfocus();
      return;
    }
    final exact = PlanPlace.resolve(q, widget.parishes);
    final best = exact != null
        ? _WhereOption(exact.label, exact)
        : _options(TextEditingValue(text: q))
            .where((o) => o.place != null)
            .firstOrNull;
    if (best != null) {
      _choose(best);
    } else {
      _focus.unfocus(); // restores the field via the focus listener
    }
  }

  Iterable<_WhereOption> _options(TextEditingValue value) {
    final q = value.text.trim();
    final typing = q.isNotEmpty && q != _meLabel && q != widget.place?.label;
    final out = <_WhereOption>[
      if (widget.hasLocation) const _WhereOption('Near me', null),
    ];
    if (!typing) return out;

    // A ZIP resolves as soon as it's whole.
    if (RegExp(r'^\d{5}').hasMatch(q)) {
      final zip = PlanPlace.resolve(q, widget.parishes);
      if (zip != null) out.add(_WhereOption('ZIP ${zip.label}', zip));
      return out;
    }

    final lower = q.toLowerCase();
    final cities = PlanPlace.cities(widget.parishes);
    final matches = [
      ...cities.where((c) => c.toLowerCase().startsWith(lower)),
      ...cities.where((c) =>
          !c.toLowerCase().startsWith(lower) &&
          c.toLowerCase().contains(lower)),
    ].take(5);
    for (final city in matches) {
      final place = PlanPlace.resolve(city, widget.parishes);
      if (place != null) out.add(_WhereOption(city, place));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;
    final base = wordStyle(accent, compact: widget.compact)
        .copyWith(decoration: TextDecoration.none);
    return SizedBox(
      width: widget.width,
      child: RawAutocomplete<_WhereOption>(
        textEditingController: _controller,
        focusNode: _focus,
        optionsBuilder: _options,
        displayStringForOption: (o) => o.place?.label ?? _meLabel,
        onSelected: _choose,
        fieldViewBuilder: (context, controller, focusNode, _) => TextField(
          controller: controller,
          focusNode: focusNode,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          onSubmitted: _submit,
          style: base,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: widget.compact
                ? const EdgeInsets.fromLTRB(10, 5, 0, 5)
                : const EdgeInsets.symmetric(vertical: 4),
            hintText: 'city or ZIP',
            hintStyle: base.copyWith(color: widget.hintColor),
            suffixIcon: Icon(Icons.edit_location_alt_outlined,
                size: widget.compact ? 16 : 18, color: accent),
            suffixIconConstraints:
                const BoxConstraints(minWidth: 26, minHeight: 22),
            // In the bar the field is a bubble like the words beside it; in
            // the planner's sentence it is an underlined blank to fill in.
            filled: widget.compact,
            fillColor: wordBubbleColor(accent),
            enabledBorder: widget.compact
                ? const OutlineInputBorder(
                    borderRadius: _bubbleRadius, borderSide: BorderSide.none)
                : UnderlineInputBorder(
                    borderSide:
                        BorderSide(color: accent.withValues(alpha: 0.5))),
            focusedBorder: widget.compact
                ? OutlineInputBorder(
                    borderRadius: _bubbleRadius,
                    borderSide: BorderSide(color: accent, width: 1.5))
                : UnderlineInputBorder(
                    borderSide: BorderSide(color: accent, width: 2)),
          ),
        ),
        optionsViewBuilder: (context, onSelected, options) => Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 240, maxHeight: 280),
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 4),
                shrinkWrap: true,
                children: [
                  for (final o in options)
                    ListTile(
                      dense: true,
                      leading: Icon(
                        o.place == null ? Icons.my_location : Icons.location_city,
                        size: 18,
                      ),
                      title: Text(o.label),
                      onTap: () => onSelected(o),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
