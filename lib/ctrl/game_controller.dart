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
        ResourceType.coal: 100,
        ResourceType.ironPlate: 120,
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
    final nextInventory = Map<ResourceType, int>.from(state.inventory);
    var nextPoints = state.points;
    final claimedResources = <(int, int)>{}; // Track resources taken by intake this tick
    final movedResources = <(int, int)>{}; // Track which resources have already moved this tick.

    // --- Phase 1: Machine Intake ---
    // Machines with recipes that have inputs try to pull from adjacent belts.
    for (int r = 0; r < state.grid.length; r++) {
      for (int c = 0; c < state.grid[r].length; c++) {
        final machine = state.grid[r][c];
        if (machine == null) continue;

        if (machine.type == MachineType.smelter) {
          final recipe = allRecipes[MachineType.smelter]!;
          var currentMachineState = nextMachineGrid[r][c]!;

          // Intake Iron Ore from Back
          if ((currentMachineState.inputBuffer[ResourceType.ironOre] ?? 0) < recipe.inputs[ResourceType.ironOre]!) {
            final backCoords = _getCoordsForDirection(r, c, _getBackInputDirection(machine.direction));
            final resourceOnBelt = _getResourceAt(backCoords);

            if (resourceOnBelt == ResourceType.ironOre && !claimedResources.contains(backCoords)) {
              final newInputs = Map<ResourceType, int>.from(currentMachineState.inputBuffer);
              newInputs.update(ResourceType.ironOre, (v) => v + 1, ifAbsent: () => 1);
              nextMachineGrid[r][c] = currentMachineState.copyWith(inputBuffer: newInputs);
              claimedResources.add(backCoords);
              currentMachineState = nextMachineGrid[r][c]!; // Refresh state
            }
          }

          // Intake Coal from Left
          if ((currentMachineState.inputBuffer[ResourceType.coal] ?? 0) < recipe.inputs[ResourceType.coal]!) {
            final leftCoords = _getCoordsForDirection(r, c, _getLeftInputDirection(machine.direction));
            final resourceOnBelt = _getResourceAt(leftCoords);

            if (resourceOnBelt == ResourceType.coal && !claimedResources.contains(leftCoords)) {
              final newInputs = Map<ResourceType, int>.from(currentMachineState.inputBuffer);
              newInputs.update(ResourceType.coal, (v) => v + 1, ifAbsent: () => 1);
              nextMachineGrid[r][c] = currentMachineState.copyWith(inputBuffer: newInputs);
              claimedResources.add(leftCoords);
            }
          }
        } else {
          // --- Other Machines: Single Input from Back ---
          final recipe = allRecipes[machine.type];
          final canTakeInput = (recipe?.inputs.isNotEmpty ?? false) || machine.type == MachineType.storage || machine.type == MachineType.grinder;

          if (canTakeInput) {
            final backCoords = _getCoordsForDirection(r, c, _getBackInputDirection(machine.direction));
            final resourceOnBelt = _getResourceAt(backCoords);

            if (resourceOnBelt != null && !claimedResources.contains(backCoords)) {
              if (machine.type == MachineType.grinder) {
                // Grinders consume any resource and turn it into points.
                nextPoints++;
                claimedResources.add(backCoords);
              } else if (machine.type == MachineType.storage) {
                nextInventory.update(resourceOnBelt, (v) => v + 1, ifAbsent: () => 1);
                claimedResources.add(backCoords);
              } else if (recipe != null && recipe.inputs.containsKey(resourceOnBelt) && (machine.inputBuffer[resourceOnBelt] ?? 0) < recipe.inputs[resourceOnBelt]!) {
                final newInputs = Map<ResourceType, int>.from(machine.inputBuffer);
                newInputs.update(resourceOnBelt, (v) => v + 1, ifAbsent: () => 1);
                nextMachineGrid[r][c] = machine.copyWith(inputBuffer: newInputs);
                claimedResources.add(backCoords);
              }
            }
          }
        }
      }
    }

    // --- Phase 2: Machine Production ---
    // Machines work on their recipes and fill their output buffers.
    for (int r = 0; r < state.grid.length; r++) {
      for (int c = 0; c < state.grid[r].length; c++) {
        // Use the machine from the next grid, as it may have received inputs this tick
        final machine = nextMachineGrid[r][c];
        if (machine == null) continue;

        final recipe = allRecipes[machine.type];

        // Handle machines with recipes
        if (recipe != null) {
          // Handle miners (no inputs). This now includes both iron and coal miners.
          if ((machine.type == MachineType.miner || machine.type == MachineType.coalMiner) && machine.outputBuffer == null) {
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

          // Handle machines with inputs (Smelters, Assemblers)
          if ((machine.type == MachineType.smelter || machine.type == MachineType.assembler) && machine.outputBuffer == null) {
            // Check if we have enough resources to start
            bool canProduce = true;
            for (final entry in recipe.inputs.entries) {
              if ((machine.inputBuffer[entry.key] ?? 0) < entry.value) {
                canProduce = false;
                break;
              }
            }

            if (canProduce) {
              // If we are not already producing, consume resources and start
              if (machine.productionProgress == 0) {
                final newInputBuffer = Map<ResourceType, int>.from(machine.inputBuffer);
                for (final entry in recipe.inputs.entries) {
                  newInputBuffer.update(entry.key, (value) => value - entry.value);
                }
                nextMachineGrid[r][c] = machine.copyWith(inputBuffer: newInputBuffer, productionProgress: 1);
              } else {
                // Continue production
                int newProgress = machine.productionProgress + 1;
                if (newProgress >= recipe.productionTime) {
                  nextMachineGrid[r][c] = machine.copyWith(productionProgress: 0, outputBuffer: recipe.outputs.keys.first);
                } else {
                  nextMachineGrid[r][c] = machine.copyWith(productionProgress: newProgress);
                }
              }
            }
          }
        }
      }
    }

    // --- Phase 3: Storage Output Provisioning ---
    // Storage buildings pull from the global inventory to fill their output.
    for (int r = 0; r < nextMachineGrid.length; r++) {
      for (int c = 0; c < nextMachineGrid[r].length; c++) {
        final machine = nextMachineGrid[r][c];
        if (machine?.type == MachineType.storage && machine!.outputBuffer == null && machine.configuredOutput != null) {
          final resourceToOutput = machine.configuredOutput!;
          if ((nextInventory[resourceToOutput] ?? 0) > 0) {
            // Decrement from inventory and place in the machine's output buffer
            nextInventory.update(resourceToOutput, (value) => value - 1);
            nextMachineGrid[r][c] = machine.copyWith(outputBuffer: resourceToOutput);
          }
        }
      }
    }

    // --- Phase 4: Machine Ejection ---
    // Machines with items in their output buffer try to place them on adjacent belts.
    for (int r = 0; r < nextMachineGrid.length; r++) {
      for (int c = 0; c < nextMachineGrid[r].length; c++) {
        final machine = nextMachineGrid[r][c];
        if (machine?.outputBuffer == null) continue;

        // Machines eject onto the tile in front of them.
        int ejectR = r, ejectC = c;
        switch (machine!.direction) {
          case Direction.up: ejectR--; break;
          case Direction.down: ejectR++; break;
          case Direction.left: ejectC--; break;
          case Direction.right: ejectC++; break;
        }

        // Check if the target tile is a valid, empty conveyor belt.
        if (_isValidAndEmpty((ejectR, ejectC), nextConveyorGrid)) {
          final resourceToEject = machine.outputBuffer!;
          // Since _isValidAndEmpty checks for null, we can safely use the ! operator here.
          nextConveyorGrid[ejectR][ejectC] = nextConveyorGrid[ejectR][ejectC]!.copyWith(resource: resourceToEject);
          nextMachineGrid[r][c] = machine.copyWith(clearOutputBuffer: true);
        }
      }
    }

    // --- Phase 5: Conveyor Belt Movement ---
    for (int r = 0; r < state.conveyorGrid.length; r++) {
      for (int c = 0; c < state.conveyorGrid[r].length; c++) {
        // We use the *original* state.conveyorGrid to calculate moves
        // to prevent items from moving multiple times in one tick.
        final conveyor = state.conveyorGrid[r][c];
        if (conveyor?.resource != null && !movedResources.contains((r, c)) && !claimedResources.contains((r, c))) {
          if (conveyor!.type == ConveyorType.splitter) {
            // --- Smart Splitter Logic ---
            final resourceToMove = conveyor.resource!;
            final frontDir = conveyor.direction;
            final rightDir = _getClockwiseDirection(conveyor.direction);

            final frontCoords = _getCoordsForDirection(r, c, frontDir);
            final rightCoords = _getCoordsForDirection(r, c, rightDir);

            bool tryMove((int, int) coords) {
              if (_isValidAndEmpty(coords, nextConveyorGrid)) {
                nextConveyorGrid[coords.$1][coords.$2] = nextConveyorGrid[coords.$1][coords.$2]?.copyWith(resource: resourceToMove);
                nextConveyorGrid[r][c] = conveyor.copyWith(clearResource: true, splitterToggle: 1 - conveyor.splitterToggle);
                movedResources.add(coords);
                return true;
              }
              return false;
            }

            if (conveyor.splitterToggle == 0) {
              // Try front, then right
              if (!tryMove(frontCoords)) {
                tryMove(rightCoords);
              }
            } else {
              // Try right, then front
              if (!tryMove(rightCoords)) {
                tryMove(frontCoords);
              }
            }
          } else {
            // --- Normal Conveyor & Merger Logic ---
            final (nextR, nextC) = _getCoordsForDirection(r, c, conveyor.direction);

            // Check if the next tile is valid and empty.
            if (_isValidAndEmpty((nextR, nextC), nextConveyorGrid)) {
              // The move is valid. Update the next state.
              final resourceToMove = conveyor.resource!;
              nextConveyorGrid[nextR][nextC] = nextConveyorGrid[nextR][nextC]?.copyWith(resource: resourceToMove);
              nextConveyorGrid[r][c] = conveyor.copyWith(clearResource: true);
              movedResources.add((nextR, nextC)); // Mark this resource as moved for this tick.
            }
          }
        }
      }
    }

    // --- Phase 6: Finalize State ---
    // Clear resources that were consumed by machine intake
    for (final coords in claimedResources) {
      final conveyor = nextConveyorGrid[coords.$1][coords.$2];
      if (conveyor != null) nextConveyorGrid[coords.$1][coords.$2] = conveyor.copyWith(clearResource: true);
    }

    state = state.copyWith(
      grid: nextMachineGrid,
      conveyorGrid: nextConveyorGrid,
      inventory: nextInventory,
      points: nextPoints,
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

  /// Places a new conveyor splitter on the grid.
  void placeSplitter(Direction direction, int row, int col) {
    if (row < 0 || row >= state.conveyorGrid.length || col < 0 || col >= state.conveyorGrid[0].length) return;
    if (state.conveyorGrid[row][col] != null) return;

    // 2. Check if player can afford it.
    if (!_canAfford(conveyorSplitterCost, 'a splitter')) return;

    // 3. Create new state components.
    final newInventory = _deductCost(conveyorSplitterCost);

    final newSplitter = Conveyor(
      direction: direction,
      row: row,
      col: col,
      type: ConveyorType.splitter,
    );
    final newGrid = state.conveyorGrid.map((rowList) => List<Conveyor?>.from(rowList)).toList();
    newGrid[row][col] = newSplitter;

    // 4. Update state.
    state = state.copyWith(conveyorGrid: newGrid, inventory: newInventory);
  }

  /// Places a new conveyor merger on the grid.
  void placeMerger(Direction direction, int row, int col) {
    if (row < 0 || row >= state.conveyorGrid.length || col < 0 || col >= state.conveyorGrid[0].length) return;
    if (state.conveyorGrid[row][col] != null) return;

    // 2. Check if player can afford it.
    if (!_canAfford(conveyorMergerCost, 'a merger')) return;

    // 3. Create new state components.
    final newInventory = _deductCost(conveyorMergerCost);

    final newMerger = Conveyor(
      direction: direction,
      row: row,
      col: col,
      type: ConveyorType.merger,
    );
    final newGrid = state.conveyorGrid.map((rowList) => List<Conveyor?>.from(rowList)).toList();
    newGrid[row][col] = newMerger;

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

  /// Rotates an existing conveyor on the grid.
  void rotateConveyor(int row, int col) {
    final conveyor = state.conveyorGrid[row][col];
    if (conveyor == null) return; // Can't rotate something that isn't there.

    // Cycle through the directions: down -> left -> up -> right -> down
    final currentDirectionIndex = Direction.values.indexOf(conveyor.direction);
    final nextDirectionIndex = (currentDirectionIndex + 1) % Direction.values.length;
    final nextDirection = Direction.values[nextDirectionIndex];

    final newGrid = state.conveyorGrid.map((rowList) => List<Conveyor?>.from(rowList)).toList();
    newGrid[row][col] = conveyor.copyWith(direction: nextDirection);

    state = state.copyWith(conveyorGrid: newGrid);
  }

  /// Rotates an existing machine on the grid.
  void rotateMachine(int row, int col) {
    final machine = state.grid[row][col];
    if (machine == null) return;

    // Cycle through the directions
    final currentDirectionIndex = Direction.values.indexOf(machine.direction);
    final nextDirectionIndex = (currentDirectionIndex + 1) % Direction.values.length;
    final nextDirection = Direction.values[nextDirectionIndex];

    final newGrid = state.grid.map((rowList) => List<Machine?>.from(rowList)).toList();
    newGrid[row][col] = machine.copyWith(direction: nextDirection);

    state = state.copyWith(grid: newGrid);
  }

  /// Cycles the output resource for a storage container.
  void cycleStorageOutput(int row, int col) {
    final machine = state.grid[row][col];
    if (machine == null || machine.type != MachineType.storage) return;

    final allResources = ResourceType.values;
    final currentOutput = machine.configuredOutput;

    // Find the index of the current selection.
    final currentIndex = currentOutput == null ? -1 : allResources.indexOf(currentOutput);

    // Cycle to the next resource, or to null (off) if at the end.
    final nextIndex = currentIndex + 1;
    final newOutput = nextIndex >= allResources.length ? null : allResources[nextIndex];

    final newGrid = state.grid.map((rowList) => List<Machine?>.from(rowList)).toList();
    newGrid[row][col] = machine.copyWith(configuredOutput: newOutput);

    state = state.copyWith(
      grid: newGrid,
      lastMessage: 'Storage set to output: ${newOutput?.name ?? 'Nothing'}',
    );
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

  Direction _getBackInputDirection(Direction machineFacing) {
    switch (machineFacing) {
      case Direction.up: return Direction.down;
      case Direction.down: return Direction.up;
      case Direction.left: return Direction.right;
      case Direction.right: return Direction.left;
    }
  }

  Direction _getLeftInputDirection(Direction machineFacing) {
    switch (machineFacing) {
      case Direction.up: return Direction.left;
      case Direction.down: return Direction.right;
      case Direction.left: return Direction.down;
      case Direction.right: return Direction.up;
    }
  }

  ResourceType? _getResourceAt((int, int) coords) {
    final r = coords.$1;
    final c = coords.$2;
    if (r >= 0 && r < state.conveyorGrid.length && c >= 0 && c < state.conveyorGrid[0].length) {
      return state.conveyorGrid[r][c]?.resource;
    }
    return null;
  }

  Direction _getClockwiseDirection(Direction dir) {
    const clockwiseMap = {
      Direction.up: Direction.right,
      Direction.right: Direction.down,
      Direction.down: Direction.left,
      Direction.left: Direction.up,
    };
    return clockwiseMap[dir]!;
  }

  (int, int) _getCoordsForDirection(int r, int c, Direction dir) {
    int nextR = r, nextC = c;
    switch (dir) {
      case Direction.up: nextR--; break;
      case Direction.down: nextR++; break;
      case Direction.left: nextC--; break;
      case Direction.right: nextC++; break;
    }
    return (nextR, nextC);
  }

  bool _isValidAndEmpty((int, int) coords, List<List<Conveyor?>> grid) {
    final r = coords.$1;
    final c = coords.$2;
    if (r >= 0 && r < grid.length && c >= 0 && c < grid[0].length) {
      // Check if the target tile has a conveyor and is empty
      return grid[r][c] != null && grid[r][c]?.resource == null;
    }
    return false;
  }
}