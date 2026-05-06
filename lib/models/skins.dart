import 'package:flutter/material.dart';

class Skin {
  final String id;
  final String name;
  final String description;
  final int price;
  final Color primary;
  final String glyphSymbol;
  bool isUnlocked;

  Skin({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.primary,
    required this.glyphSymbol,
    this.isUnlocked = false,
  });

  static final List<Skin> all = [
    Skin(
      id: 'default',
      name: 'Conduit',
      description: 'The standard pulse of the void.',
      price: 0,
      primary: const Color(0xFF00CFFF),
      glyphSymbol: 'circle.hexagongrid.fill',
      isUnlocked: true,
    ),
    Skin(
      id: 'ember',
      name: 'Ember',
      description: 'A burning fragment from the deep.',
      price: 50,
      primary: const Color(0xFFFF8C00),
      glyphSymbol: 'flame.fill',
    ),
    Skin(
      id: 'lattice',
      name: 'Lattice',
      description: 'Structured energy. Precise and cold.',
      price: 100,
      primary: const Color(0xFF9B59FF),
      glyphSymbol: 'circle.grid.cross',
    ),
  ];
}

class LeaderboardEntry {
  final String id;
  final String playerName;
  final int score;
  final DateTime date;
  int rank;

  LeaderboardEntry({
    required this.id,
    required this.playerName,
    required this.score,
    required this.date,
    this.rank = 0,
  });

  static final List<LeaderboardEntry> mock = [
    LeaderboardEntry(id: 'a', playerName: 'VoidRunner', score: 142, date: DateTime.now()),
    LeaderboardEntry(id: 'b', playerName: 'Cipher', score: 97, date: DateTime.now()),
    LeaderboardEntry(id: 'c', playerName: 'NullStar', score: 88, date: DateTime.now()),
    LeaderboardEntry(id: 'd', playerName: 'Ash', score: 61, date: DateTime.now()),
    LeaderboardEntry(id: 'e', playerName: 'Pulse', score: 44, date: DateTime.now()),
  ];
}
