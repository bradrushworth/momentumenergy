import 'package:intl/intl.dart';

/// The app's two date formats, hoisted so every screen renders a date
/// identically (and so building a `DateFormat` — not a cheap object — happens
/// once rather than per card, per rebuild).
///
/// `dayFormat` is the card/context-line format (`Tue 8 Jul`); the year is
/// added only where the range's end needs disambiguating (`dayYearFormat`).
final DateFormat dayFormat = DateFormat('E d MMM');
final DateFormat dayYearFormat = DateFormat('E d MMM yyyy');
