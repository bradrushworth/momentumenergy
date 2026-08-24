import 'package:flutter/material.dart';

/// Momentum Energy's own palette, sampled from momentumenergy.com.au: the deep
/// indigo they paint nearly every page in, the lifted indigo of their cards,
/// and the mint-to-cyan accent their logo swoosh and buttons use.
///
/// This app is NOT affiliated with Momentum Energy. It reads a usage export
/// their customers download from MyAccount, so it speaks the visual language
/// those customers already associate with their account. What it must never do
/// is pass for an official app: their logo, wordmark (Poppins) and artwork stay
/// theirs, and the mark, layout and naming here stay ours.
///
/// Amber Electric's palette (see ../../amber/lib/theme.dart) is a close cousin
/// — both retailers brand navy-plus-mint. The two apps are told apart by
/// Momentum's deeper indigo ground and its cyan-into-mint gradient, against
/// Amber's slate navy and flat mint.
class MomentumPalette {
  MomentumPalette._();

  /// Page background — the near-black indigo their site sits on.
  static const indigo = Color(0xFF000045);

  /// Cards and app bars: the lifted indigo their content panels use.
  static const surface = Color(0xFF001B63);

  /// Chart placeholder while a file parses.
  static const skeleton = Color(0xFF0A2A80);

  /// The accent, and the warm end of the logo gradient.
  static const mint = Color(0xFF2CF2AE);

  /// The cool end of that gradient, used for the icon bars.
  static const cyan = Color(0xFF4FD8F0);

  /// Pressed/disabled mint.
  static const mintDeep = Color(0xFF12B183);

  /// Secondary text on [indigo] (labels, captions, axis furniture).
  static const muted = Color(0xFF98A6D8);

  /// Slightly brighter secondary text, for small type that must stay legible.
  static const mutedBright = Color(0xFFBAC6EE);
}
