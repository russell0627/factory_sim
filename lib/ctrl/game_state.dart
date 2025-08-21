import 'package:factory_sim/models/conveyor.dart';
import 'package:factory_sim/models/machine.dart';
import 'package:factory_sim/models/rail.dart';
import 'package:factory_sim/models/train.dart';
import 'package:factory_sim/models/pipe.dart';
import 'package:factory_sim/models/factory_core.dart';
import 'package:factory_sim/models/research.dart';
import 'package:factory_sim/models/resource.dart';
import 'package:factory_sim/models/tool.dart';
import 'package:flutter/foundation.dart';

@immutable
class GameState {
  const GameState({
    required this.grid,
    required this.conveyorGrid,
    required this.railGrid,
    required this.trains,
    required this.pipeGrid,
    required this.resourceGrid,
    required this.inventory,
    this.gameTick = 0,
    this.lastMessage,
    this.selectedTool = Tool.inspect,
    this.points = 0,
    this.unlockedResearch = const {},
    this.powerCapacity = 0,
    this.powerDemand = 0,
    this.factoryCore,
  });

  final List<List<Machine?>> grid;
  final List<List<Conveyor?>> conveyorGrid;
  final List<List<Rail?>> railGrid;
  final List<Train> trains;
  final List<List<Pipe?>> pipeGrid;
  final List<List<ResourceType?>> resourceGrid;
  final Map<ResourceType, int> inventory;
  final int gameTick;
  final String? lastMessage;
  final Tool selectedTool;
  final int points;
  final Set<ResearchType> unlockedResearch;
  final int powerCapacity;
  final int powerDemand;
  final FactoryCoreState? factoryCore;

  GameState copyWith({
    List<List<Machine?>>? grid,
    List<List<Conveyor?>>? conveyorGrid,
    List<List<Rail?>>? railGrid,
    List<Train>? trains,
    List<List<Pipe?>>? pipeGrid,
    List<List<ResourceType?>>? resourceGrid,
    Map<ResourceType, int>? inventory,
    int? gameTick,
    String? lastMessage,
    bool clearLastMessage = false,
    Tool? selectedTool,
    int? points,
    Set<ResearchType>? unlockedResearch,
    int? powerCapacity,
    int? powerDemand,
    FactoryCoreState? factoryCore,
  }) {
    return GameState(
      grid: grid ?? this.grid,
      conveyorGrid: conveyorGrid ?? this.conveyorGrid,
      railGrid: railGrid ?? this.railGrid,
      trains: trains ?? this.trains,
      pipeGrid: pipeGrid ?? this.pipeGrid,
      resourceGrid: resourceGrid ?? this.resourceGrid,
      inventory: inventory ?? this.inventory,
      gameTick: gameTick ?? this.gameTick,
      lastMessage: clearLastMessage ? null : lastMessage ?? this.lastMessage,
      selectedTool: selectedTool ?? this.selectedTool,
      points: points ?? this.points,
      unlockedResearch: unlockedResearch ?? this.unlockedResearch,
      powerCapacity: powerCapacity ?? this.powerCapacity,
      powerDemand: powerDemand ?? this.powerDemand,
      factoryCore: factoryCore ?? this.factoryCore,
    );
  }

  @override
  bool operator ==(Object other) => identical(this, other) || other is GameState && runtimeType == other.runtimeType && grid == other.grid && conveyorGrid == other.conveyorGrid && railGrid == other.railGrid && trains == other.trains && pipeGrid == other.pipeGrid && resourceGrid == other.resourceGrid && inventory == other.inventory && gameTick == other.gameTick && lastMessage == other.lastMessage && selectedTool == other.selectedTool && points == other.points && unlockedResearch == other.unlockedResearch && powerCapacity == other.powerCapacity && powerDemand == other.powerDemand && factoryCore == other.factoryCore;

  @override
  int get hashCode => grid.hashCode ^ conveyorGrid.hashCode ^ railGrid.hashCode ^ trains.hashCode ^ pipeGrid.hashCode ^ resourceGrid.hashCode ^ inventory.hashCode ^ gameTick.hashCode ^ lastMessage.hashCode ^ selectedTool.hashCode ^ points.hashCode ^ unlockedResearch.hashCode ^ powerCapacity.hashCode ^ powerDemand.hashCode ^ factoryCore.hashCode;
}