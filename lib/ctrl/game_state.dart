import 'package:factory_sim/models/machine.dart';
import 'package:factory_sim/models/conveyor.dart';
import 'package:factory_sim/models/tool.dart';
import 'package:factory_sim/models/resource.dart';
import 'package:flutter/foundation.dart';

/// Represents the state of the game.
///
/// This class is immutable. To change the state, create a new instance
/// using the `copyWith` method.
class GameState {
  const GameState({
    this.grid = const [],
    this.conveyorGrid = const [],
    this.inventory = const {},
    this.gameTick = 0,
    this.lastMessage,
    this.selectedTool = Tool.miner,
  });

  /// The 2D grid representing the factory floor.
  /// A null value means the cell is empty.
  final List<List<Machine?>> grid;

  /// The 2D grid for conveyor belts.
  /// A null value means the cell is empty.
  final List<List<Conveyor?>> conveyorGrid;

  /// The player's central inventory of resources.
  final Map<ResourceType, int> inventory;

  /// A counter that increments with each game loop, representing time.
  final int gameTick;

  /// A message to be displayed to the user, e.g., for errors.
  final String? lastMessage;

  /// The tool currently selected by the player.
  final Tool selectedTool;

  // This method allows you to create a new copy of the state with
  // updated values. For now, it just returns a new empty state.
  GameState copyWith({
    List<List<Machine?>>? grid,
    List<List<Conveyor?>>? conveyorGrid,
    Map<ResourceType, int>? inventory,
    int? gameTick,
    String? lastMessage,
    Tool? selectedTool,
    bool clearLastMessage = false,
  }) {
    return GameState(
      grid: grid ?? this.grid,
      conveyorGrid: conveyorGrid ?? this.conveyorGrid,
      inventory: inventory ?? this.inventory,
      gameTick: gameTick ?? this.gameTick,
      lastMessage: clearLastMessage ? null : lastMessage ?? this.lastMessage,
      selectedTool: selectedTool ?? this.selectedTool,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GameState && runtimeType == other.runtimeType && listEquals(grid, other.grid) && listEquals(conveyorGrid, other.conveyorGrid) && mapEquals(inventory, other.inventory) && gameTick == other.gameTick && lastMessage == other.lastMessage && selectedTool == other.selectedTool;

  @override
  int get hashCode => grid.hashCode ^ conveyorGrid.hashCode ^ inventory.hashCode ^ gameTick.hashCode ^ lastMessage.hashCode ^ selectedTool.hashCode;
}