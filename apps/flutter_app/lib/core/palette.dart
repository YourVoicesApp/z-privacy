// The visual language, from the design boards — one file, so a colour is never
// invented at the place it is used.
//
// The meaning of each colour is the part that matters, and it is the same meaning
// the boards gave it:
//
//   clay   — Z Privacy itself: protection, the brand, anything the app did *for* you
//   river  — the vault: an identity the app knows by name
//   amber  — a suggestion: unanswered, still in the clear, waiting for your word
//   paper  — this device
//   white  — what leaves
//
// Nothing here decides behaviour. If a state is only a colour, it is not a state.
import 'package:flutter/material.dart';

class Zc {
  Zc._();

  // Ground
  static const paper = Color(0xFFF6F4EF);
  static const card = Color(0xFFFFFFFF);
  static const warmCard = Color(0xFFFBF7EF);
  static const line = Color(0xFFE4E0D6);
  static const lineSoft = Color(0xFFEDE7DA);

  // Ink
  static const ink = Color(0xFF17181B);
  static const ink2 = Color(0xFF4E545A);
  static const ink3 = Color(0xFF5E6469);
  static const ink4 = Color(0xFF8A8F95);

  // Protection — the app's own hand
  static const clay = Color(0xFFA85422);
  static const clayDeep = Color(0xFF8F4318);
  static const clayWash = Color(0xFFF7E7DA);
  static const clayEdge = Color(0xFFE0BFA5);

  // The vault — who, not what
  static const river = Color(0xFF1F5C97);
  static const riverWash = Color(0xFFE8F0F7);

  // A suggestion — the only colour that means «not decided»
  static const amber = Color(0xFF7A5A2C);
  static const amberWash = Color(0xFFF1E8D8);
  static const amberEdge = Color(0xFFC08149);

  // Text
  static const mono = 'monospace';

  static const h1 = TextStyle(fontSize: 25, height: 1.15, fontWeight: FontWeight.w600, color: ink);
  static const h2 = TextStyle(fontSize: 17, height: 1.25, fontWeight: FontWeight.w600, color: ink);
  static const body = TextStyle(fontSize: 14, height: 1.5, color: ink2);
  static const small = TextStyle(fontSize: 12.5, height: 1.45, color: ink3);
  static const tiny = TextStyle(fontSize: 11, height: 1.4, color: ink4, letterSpacing: 0.5);
  static const label = TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: ink4, letterSpacing: 1.1);
  static const number = TextStyle(fontSize: 27, fontWeight: FontWeight.w600, color: ink, height: 1.0);

  static const document = TextStyle(fontSize: 14.5, height: 1.75, color: ink);
  static const token = TextStyle(fontFamily: mono, fontSize: 13, height: 1.75, color: clayDeep);

  static BoxDecoration panel({Color? fill, Color? edge, double radius = 12}) => BoxDecoration(
        color: fill ?? card,
        border: Border.all(color: edge ?? line),
        borderRadius: BorderRadius.circular(radius),
      );
}
