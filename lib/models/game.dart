import 'package:mygame/models/player.dart';

enum GameState { WAITING, RUNNING, FINISHED }

class Game {
  final String id;
  final String gameCode;
  final GameState state;
  final String winningPattern;
  final List<int> calledNumbers;
  final List<Player> players;
  final List<Player> winners;
  final DateTime createdAt;

  Game({
    required this.id,
    required this.gameCode,
    this.state = GameState.WAITING,
    required this.winningPattern,
    this.calledNumbers = const [],
    this.players = const [],
    this.winners = const [],
    required this.createdAt,
  });
}
