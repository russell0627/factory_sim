import 'package:factory_sim/models/conveyor.dart';
import 'package:factory_sim/models/machine.dart';
import 'package:factory_sim/models/resource.dart';
import 'package:factory_sim/models/tool.dart';
import 'package:flutter/foundation.dart';

@immutable
class GameState {
  const GameState({
    required this.grid,
    required this.conveyorGrid,
    required this.inventory,
    this.gameTick = 0,
    this.lastMessage,
    this.selectedTool = Tool.inspect,
    this.points = 0,
  });

  final List<List<Machine?>> grid;
  final List<List<Conveyor?>> conveyorGrid;
  final Map<ResourceType, int> inventory;
  final int gameTick;
  final String? lastMessage;
  final Tool selectedTool;
  final int points;

  GameState copyWith({
    List<List<Machine?>>? grid,
    List<List<Conveyor?>>? conveyorGrid,
    Map<ResourceType, int>? inventory,
    int? gameTick,
    String? lastMessage,
    bool clearLastMessage = false,
    Tool? selectedTool,
    int? points,
  }) {
    return GameState(
      grid: grid ?? this.grid,
      conveyorGrid: conveyorGrid ?? this.conveyorGrid,
      inventory: inventory ?? this.inventory,
      gameTick: gameTick ?? this.gameTick,
      lastMessage: clearLastMessage ? null : lastMessage ?? this.lastMessage,
      selectedTool: selectedTool ?? this.selectedTool,
      points: points ?? this.points,
    );
  }

  @override
  bool operator ==(Object other) => identical(this, other) || other is GameState && runtimeType == other.runtimeType && grid == other.grid && conveyorGrid == other.conveyorGrid && inventory == other.inventory && gameTick == other.gameTick && lastMessage == other.lastMessage && selectedTool == other.selectedTool && points == other.points;

  @override
  int get hashCode => grid.hashCode ^ conveyorGrid.hashCode ^ inventory.hashCode ^ gameTick.hashCode ^ lastMessage.hashCode ^ selectedTool.hashCode ^ points.hashCode;
}