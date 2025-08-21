import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:factory_sim/ctrl/game_state.dart';
import 'package:factory_sim/models/tool.dart';
import 'package:factory_sim/models/machine.dart';
import 'package:factory_sim/models/conveyor.dart';
import 'package:factory_sim/models/resource.dart';
import 'package:factory_sim/models/recipe.dart';
import 'package:factory_sim/models/building_data.dart';

part 'game_controller.g.dart';

@riverpod
class GameController extends _$GameController {
  Timer? _timer;

  @override
  GameState build() {
    // This is where you would initialize your game state.
    const gridSize = 10;
    final initialState = GameState(
      grid: List.generate(gridSize, (_) => List.filled(gridSize, null)),
      conveyorGrid: List.generate(gridSize, (_) => List.filled(gridSize, null)),
      inventory: {
        ResourceType.ironOre: 100,
        ResourceType.copperOre: 50,
        ResourceType.ironPlate: 20, // Starting plates to build first machines
      },
    );

    // Start the game loop when the provider is first created.
    _startTimer();

    // Make sure to cancel the timer when the provider is disposed.
    ref.onDispose(() {
      _timer?.cancel();
    });

    return initialState;
  }

  void _startTimer() {
    // Set up a periodic timer to call the tick method every second.
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  /// The main game loop logic.
  void tick() {
    // Create mutable copies of the state grids to calculate the next frame.
    final nextMachineGrid = state.grid.map((row) => List<Machine?>.from(row)).toList();
    final nextConveyorGrid = state.conveyorGrid.map((row) => List<Conveyor?>.from(row)).toList();
    final movedResources = <(int, int)>{}; // Track which resources have already moved this tick.

    // --- Phase 1: Machine Production ---
    // Machines work on their recipes and fill their output buffers.
    for (int r = 0; r < state.grid.length; r++) {
      for (int c = 0; c < state.grid[r].length; c++) {
        final machine = state.grid[r][c];
        if (machine == null) continue;

        final recipe = allRecipes[machine.type];
        if (recipe == null) continue;

        // For now, we only handle miners, which have no inputs.
        if (machine.type == MachineType.miner && machine.outputBuffer == null) {
          int newProgress = machine.productionProgress + 1;
          if (newProgress >= recipe.productionTime) {
            // Production complete!
            newProgress = 0;
            final outputResource = recipe.outputs.keys.first;
            nextMachineGrid[r][c] = machine.copyWith(
              productionProgress: newProgress,
              outputBuffer: outputResource,
            );
          } else {
            // Continue production.
            nextMachineGrid[r][c] = machine.copyWith(productionProgress: newProgress);
          }
        }
      }
    }

    // --- Phase 2: Machine Ejection ---
    // Machines with items in their output buffer try to place them on adjacent belts.
    for (int r = 0; r < nextMachineGrid.length; r++) {
      for (int c = 0; c < nextMachineGrid[r].length; c++) {
        final machine = nextMachineGrid[r][c];
        if (machine?.outputBuffer == null) continue;

        // For now, machines eject onto the tile below them.
        // A more robust solution would check all adjacent tiles for a valid belt.
        final (ejectR, ejectC) = (r + 1, c);

        // Check if the target tile is a valid, empty conveyor belt.
        if (ejectR < state.conveyorGrid.length && nextConveyorGrid[ejectR][ejectC]?.resource == null) {
          final resourceToEject = machine!.outputBuffer!;
          nextConveyorGrid[ejectR][ejectC] = nextConveyorGrid[ejectR][ejectC]?.copyWith(resource: resourceToEject);
          nextMachineGrid[r][c] = machine.copyWith(clearOutputBuffer: true);
        }
      }
    }

    // --- Phase 3: Conveyor Belt Movement ---
    for (int r = 0; r < state.conveyorGrid.length; r++) {
      for (int c = 0; c < state.conveyorGrid[r].length; c++) {
        // We use the *original* state.conveyorGrid to calculate moves
        // to prevent items from moving multiple times in one tick.
        final conveyor = state.conveyorGrid[r][c]; 
        if (conveyor?.resource != null && !movedResources.contains((r, c))) {
          // This conveyor has an item, let's try to move it.
          int nextR = r, nextC = c;
          switch (conveyor!.direction) {
            case Direction.up:
              nextR--;
            case Direction.down:
              nextR++;
            case Direction.left:
              nextC--;
            case Direction.right:
              nextC++;
          }

          // Check if the next tile is valid and empty.
          if (nextR >= 0 && nextR < state.conveyorGrid.length && nextC >= 0 && nextC < state.conveyorGrid[0].length && nextConveyorGrid[nextR][nextC]?.resource == null) {
            // The move is valid. Update the next state.
            final resourceToMove = conveyor.resource!;
            nextConveyorGrid[nextR][nextC] = nextConveyorGrid[nextR][nextC]?.copyWith(resource: resourceToMove);
            nextConveyorGrid[r][c] = conveyor.copyWith(clearResource: true);
            movedResources.add((nextR, nextC)); // Mark this resource as moved for this tick.
          }
        }
      }
    }

    // --- Phase 4: Update State ---
    state = state.copyWith(
      grid: nextMachineGrid,
      conveyorGrid: nextConveyorGrid,
      gameTick: state.gameTick + 1,
    );
  }

  /// Places a new machine on the grid.
  void placeMachine(MachineType type, int row, int col) {
    // 1. Check if the cell is within bounds and empty.
    if (row < 0 || row >= state.grid.length || col < 0 || col >= state.grid[0].length) return;
    if (state.grid[row][col] != null) return;

    // 2. Check if the player can afford it.
    final cost = machineCosts[type];
    if (cost == null || !_canAfford(cost, 'a ${type.name}')) return;

    // 3. Create the new state components.
    final newInventory = _deductCost(cost);

    final newMachine = Machine(type: type, row: row, col: col);
    final newGrid = state.grid.map((rowList) => List<Machine?>.from(rowList)).toList();
    newGrid[row][col] = newMachine;

    // 4. Update the state.
    state = state.copyWith(
      grid: newGrid,
      inventory: newInventory,
    );
  }

  /// Removes a machine from the grid.
  void removeMachine(int row, int col) {
    if (row < 0 || row >= state.grid.length || col < 0 || col >= state.grid[0].length) return;
    if (state.grid[row][col] == null) return;

    final newGrid = state.grid.map((rowList) => List<Machine?>.from(rowList)).toList();
    newGrid[row][col] = null;

    state = state.copyWith(grid: newGrid);
  }

  /// Places a new conveyor on the grid.
  void placeConveyor(Direction direction, int row, int col) {
    if (row < 0 || row >= state.conveyorGrid.length || col < 0 || col >= state.conveyorGrid[0].length) return;
    if (state.conveyorGrid[row][col] != null) return;

    // 2. Check if player can afford it.
    if (!_canAfford(conveyorCost, 'a conveyor')) return;

    // 3. Create new state components.
    final newInventory = _deductCost(conveyorCost);

    final newConveyor = Conveyor(direction: direction, row: row, col: col);
    final newGrid = state.conveyorGrid.map((rowList) => List<Conveyor?>.from(rowList)).toList();
    newGrid[row][col] = newConveyor;

    // 4. Update state.
    state = state.copyWith(conveyorGrid: newGrid, inventory: newInventory);
  }

  /// Removes a conveyor from the grid.
  void removeConveyor(int row, int col) {
    if (row < 0 || row >= state.conveyorGrid.length || col < 0 || col >= state.conveyorGrid[0].length) return;
    if (state.conveyorGrid[row][col] == null) return;

    final newGrid = state.conveyorGrid.map((rowList) => List<Conveyor?>.from(rowList)).toList();
    newGrid[row][col] = null;

    state = state.copyWith(conveyorGrid: newGrid);
  }

  /// Clears the user-facing message in the game state.
  void clearUserMessage() {
    state = state.copyWith(clearLastMessage: true);
  }

  /// Sets the player's currently selected tool.
  void selectTool(Tool tool) {
    state = state.copyWith(selectedTool: tool);
  }

  // --- Private Helper Methods ---

  bool _canAfford(Map<ResourceType, int> cost, String buildingName) {
    for (final entry in cost.entries) {
      if ((state.inventory[entry.key] ?? 0) < entry.value) {
        state = state.copyWith(lastMessage: 'Not enough ${entry.key.name} to build $buildingName.');
        return false;
      }
    }
    return true;
  }

  Map<ResourceType, int> _deductCost(Map<ResourceType, int> cost) {
    final newInventory = Map<ResourceType, int>.from(state.inventory);
    for (final entry in cost.entries) {
      newInventory.update(
        entry.key,
        (value) => value - entry.value,
        ifAbsent: () => -entry.value,
      );
    }
    return newInventory;
  }
}