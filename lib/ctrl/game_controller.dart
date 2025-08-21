import 'dart:async';
import 'dart:math';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:factory_sim/ctrl/game_state.dart';
import 'package:factory_sim/models/pipe.dart';
import 'package:factory_sim/models/rail.dart';
import 'package:factory_sim/models/train.dart';
import 'package:factory_sim/models/tool.dart';
import 'package:factory_sim/models/turret_data.dart';
import 'package:factory_sim/models/research.dart';
import 'package:factory_sim/models/machine.dart';
import 'package:factory_sim/models/conveyor.dart';
import 'package:factory_sim/models/resource.dart';
import 'package:factory_sim/models/factory_core.dart';
import 'package:factory_sim/models/drone.dart';
import 'package:factory_sim/models/train_stop_data.dart';
import 'package:factory_sim/models/enemy.dart';
import 'package:factory_sim/models/player.dart';
import 'package:factory_sim/models/recipe.dart';
import 'package:factory_sim/models/building_data.dart';
import 'package:factory_sim/models/power_data.dart';

part 'game_controller.g.dart';

const Map<MachineType, int> pollutionGeneration = {
  MachineType.miner: 1,
  MachineType.coalMiner: 1,
  MachineType.copperMiner: 1,
  MachineType.smelter: 3,
  MachineType.coalGenerator: 5,
  MachineType.refinery: 4,
  MachineType.chemicalPlant: 4,
  // T2
  MachineType.minerT2: 1,
  MachineType.coalMinerT2: 1,
  MachineType.copperMinerT2: 1,
  MachineType.smelterT2: 3,
};

@riverpod
class GameController extends _$GameController {
  Timer? _timer;

  @override
  GameState build() {
    // This is where you would initialize your game state.
    const gridSize = 20;

    // Generate resource patches
    final resourceGrid = List.generate(gridSize, (_) => List<ResourceType?>.filled(gridSize, null));
    final random = Random();
    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        final val = random.nextDouble();
        if (val < 0.05) { // 5% chance for iron
          resourceGrid[r][c] = ResourceType.ironOre;
        } else if (val < 0.08) { // 3% chance for copper
          resourceGrid[r][c] = ResourceType.copperOre;
        } else if (val < 0.12) { // 4% chance for coal
          resourceGrid[r][c] = ResourceType.coal;
        } else if (val < 0.15) { // 3% chance for water
          resourceGrid[r][c] = ResourceType.water;
        } else if (val < 0.17) { // 2% chance for oil
          resourceGrid[r][c] = ResourceType.oilSeep;
        }
      }
    }

    // Spawn enemy nests
    final enemyNests = <EnemyNest>[];
    int nestsToSpawn = 3;
    while (nestsToSpawn > 0) {
      final r = random.nextInt(gridSize);
      final c = random.nextInt(gridSize);
      // Spawn away from the center
      if (resourceGrid[r][c] == null && (r < 2 || r > gridSize - 3 || c < 2 || c > gridSize - 3)) {
        enemyNests.add(EnemyNest(row: r, col: c));
        nestsToSpawn--;
      }
    }

    final initialState = GameState(
      grid: List.generate(gridSize, (_) => List.filled(gridSize, null)),
      conveyorGrid: List.generate(gridSize, (_) => List.filled(gridSize, null)),
      railGrid: List.generate(gridSize, (_) => List.filled(gridSize, null)),
      trains: const [],
      pipeGrid: List.generate(gridSize, (_) => List.filled(gridSize, null)),
      player: Player(position: (gridSize ~/ 2, gridSize ~/ 2)),
      pollutionGrid: List.generate(gridSize, (_) => List.filled(gridSize, 0)),
      enemyNests: enemyNests,
      enemies: const [],
      inventory: {
        ResourceType.ironOre: 100,
        ResourceType.copperOre: 50,
        ResourceType.coal: 100,
        ResourceType.ironPlate: 90, // Enough for basic setup before research
      },
      resourceGrid: resourceGrid,
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
    final nextPipeGrid = state.pipeGrid.map((row) => List<Pipe?>.from(row)).toList();
    final nextConveyorGrid = state.conveyorGrid.map((row) => List<Conveyor?>.from(row)).toList();
    final nextPollutionGrid = state.pollutionGrid.map((row) => List<int>.from(row)).toList();
    var nextEnemyNests = List<EnemyNest>.from(state.enemyNests);
    var nextPlayer = state.player;
    var nextEnemies = List<Enemy>.from(state.enemies);
    final nextTrains = state.trains.map((t) => t).toList(); // Trains are immutable, so a shallow copy is fine for now
    final nextInventory = Map<ResourceType, int>.from(state.inventory);
    var nextPoints = state.points;
    var nextFactoryCore = state.factoryCore;
    var nextEnemyId = state.nextEnemyId;
    final claimedResources = <(int, int)>{}; // Track resources taken by intake this tick
    final claimedPipes = <(int, int)>{}; // Track pipes taken by fluid intake this tick
    final movedResources = <(int, int)>{}; // Track which resources have already moved this tick.
    final movedPipes = <(int, int)>{}; // Track which pipes have already moved this tick.
    final random = Random();

    // --- Phase -1: Player Hand Crafting ---
    if (nextPlayer.craftingQueue.isNotEmpty) {
      final recipe = nextPlayer.craftingQueue.first;
      final newProgress = nextPlayer.craftingProgress + 1;
      if (newProgress >= recipe.productionTime) {
        // Crafting complete
        final resource = recipe.outputs.keys.first;
        final amount = recipe.outputs.values.first;
        nextInventory.update(resource, (v) => v + amount, ifAbsent: () => amount);
        final newQueue = List<Recipe>.from(nextPlayer.craftingQueue)..removeAt(0);
        nextPlayer = nextPlayer.copyWith(craftingQueue: newQueue, clearCrafting: newQueue.isEmpty);
      } else {
        // Continue crafting
        nextPlayer = nextPlayer.copyWith(craftingProgress: newProgress);
      }
    }

    // --- Phase 0: Power Management ---
    var totalDemand = 0;
    var totalCapacity = 0;

    // --- Step 1: Identify all power sources and find all machines connected to them ---
    final powerSources = <(int, int, int)>{}; // r, c, radius
    final connectedMachineCoords = <(int, int)>{}; // r, c

    for (int r = 0; r < state.grid.length; r++) {
      for (int c = 0; c < state.grid[r].length; c++) {
        final machine = state.grid[r][c];
        if (machine == null) continue;
        if (powerGeneration.containsKey(machine.type)) {
          powerSources.add((r, c, 4)); // Generator radius
        } else if (machine.type == MachineType.powerPole) {
          powerSources.add((r, c, 3)); // Pole radius
        }
      }
    }

    for (int r = 0; r < state.grid.length; r++) {
      for (int c = 0; c < state.grid[r].length; c++) {
        final machine = state.grid[r][c];
        if (machine == null) continue;

        for (final source in powerSources) {
          // Use Manhattan distance for a diamond-shaped coverage area
          final distance = (r - source.$1).abs() + (c - source.$2).abs();
          if (distance <= source.$3) {
            connectedMachineCoords.add((r, c));
            break; // Once connected, no need to check other sources
          }
        }
      }
    }

    // --- Step 2: Calculate capacity from fueled generators and consume their fuel ---
    for (final sourceCoords in powerSources) {
      final machine = state.grid[sourceCoords.$1][sourceCoords.$2];
      if (machine != null && powerGeneration.containsKey(machine.type)) {
        if ((machine.inputBuffer[ResourceType.coal] ?? 0) > 0) {
          totalCapacity += powerGeneration[machine.type]!;
          final newInputs = Map<ResourceType, int>.from(machine.inputBuffer);
          newInputs.update(ResourceType.coal, (v) => v - 1);
          nextMachineGrid[sourceCoords.$1][sourceCoords.$2] = machine.copyWith(inputBuffer: newInputs);
        }
      }
    }

    // --- Step 3: Calculate demand from ONLY connected machines ---
    for (final coords in connectedMachineCoords) {
      final machine = state.grid[coords.$1][coords.$2];
      if (machine != null) totalDemand += powerConsumption[machine.type] ?? 0;
    }

    // --- Step 4: Determine brownout and update power status for all machines ---
    final hasPower = totalCapacity >= totalDemand;
    for (int r = 0; r < nextMachineGrid.length; r++) {
      for (int c = 0; c < nextMachineGrid[r].length; c++) {
        final machine = nextMachineGrid[r][c];
        if (machine == null) continue;

        if (powerConsumption.containsKey(machine.type)) {
          final isConnected = connectedMachineCoords.contains((r, c));
          nextMachineGrid[r][c] = machine.copyWith(isPowered: isConnected && hasPower);
        } else if (powerGeneration.containsKey(machine.type)) {
          // A generator is "powered" if it has fuel.
          final hasFuel = (nextMachineGrid[r][c]?.inputBuffer[ResourceType.coal] ?? 0) > 0;
          nextMachineGrid[r][c] = machine.copyWith(isPowered: hasFuel);
        }
      }
    }

    // --- Phase 0.5: Pollution Generation & Spreading ---
    // Generate
    for (int r = 0; r < state.grid.length; r++) {
      for (int c = 0; c < state.grid[r].length; c++) {
        final machine = state.grid[r][c];
        if (machine != null && machine.isPowered) {
          final pollution = pollutionGeneration[machine.type] ?? 0;
          if (pollution > 0) {
            nextPollutionGrid[r][c] += pollution;
          }
        }
      }
    }
    // TODO: Add pollution spreading logic

    // --- Phase 1: Machine Intake ---
    // Machines with recipes that have inputs try to pull from adjacent belts.
    for (int r = 0; r < nextMachineGrid.length; r++) {
      for (int c = 0; c < nextMachineGrid[r].length; c++) {
        final machine = nextMachineGrid[r][c];
        if (machine == null) continue;

        final isSmelter = machine.type == MachineType.smelter || machine.type == MachineType.smelterT2;
        final isAssembler = machine.type == MachineType.assembler || machine.type == MachineType.assemblerT2;
        final isTurret = machine.type == MachineType.gunTurret;
        final isRefinery = machine.type == MachineType.refinery;

        if (isSmelter) {
          var currentMachineState = nextMachineGrid[r][c]!;
          final backCoords = _getCoordsForDirection(r, c, _getBackInputDirection(machine.direction));
          final resourceOnBelt = _getResourceAt(backCoords);

          // Smelters take ore from the back
          if (resourceOnBelt != null && !claimedResources.contains(backCoords)) {
            bool tookResource = false;
            // Try to take Iron Ore
            if (resourceOnBelt == ResourceType.ironOre && (currentMachineState.inputBuffer[ResourceType.ironOre] ?? 0) < 2) {
              final newInputs = Map<ResourceType, int>.from(currentMachineState.inputBuffer);
              newInputs.update(ResourceType.ironOre, (v) => v + 1, ifAbsent: () => 1);
              nextMachineGrid[r][c] = currentMachineState.copyWith(inputBuffer: newInputs);
              tookResource = true;
            }
            // Try to take Copper Ore (if researched)
            else if (resourceOnBelt == ResourceType.copperOre && state.unlockedResearch.contains(ResearchType.copperProcessing) && (currentMachineState.inputBuffer[ResourceType.copperOre] ?? 0) < 2) {
              final newInputs = Map<ResourceType, int>.from(currentMachineState.inputBuffer);
              newInputs.update(ResourceType.copperOre, (v) => v + 1, ifAbsent: () => 1);
              nextMachineGrid[r][c] = currentMachineState.copyWith(inputBuffer: newInputs);
              tookResource = true;
            }

            if (tookResource) {
              claimedResources.add(backCoords);
              currentMachineState = nextMachineGrid[r][c]!; // Refresh state
            }
          }

          // Intake Coal from Left
          if ((currentMachineState.inputBuffer[ResourceType.coal] ?? 0) < 2) {
            final leftCoords = _getCoordsForDirection(r, c, _getLeftInputDirection(machine.direction));
            final resourceOnLeftBelt = _getResourceAt(leftCoords);

            if (resourceOnLeftBelt == ResourceType.coal && !claimedResources.contains(leftCoords)) {
              final newInputs = Map<ResourceType, int>.from(currentMachineState.inputBuffer);
              newInputs.update(ResourceType.coal, (v) => v + 1, ifAbsent: () => 1);
              nextMachineGrid[r][c] = currentMachineState.copyWith(inputBuffer: newInputs);
              claimedResources.add(leftCoords);
            }
          }
        } else if (isTurret) {
          // Turrets take ammo from the back
          final backCoords = _getCoordsForDirection(r, c, _getBackInputDirection(machine.direction));
          final resourceOnBelt = _getResourceAt(backCoords);
          if (resourceOnBelt == ResourceType.ammunition && (machine.inputBuffer[ResourceType.ammunition] ?? 0) < 20) {
            final newInputs = Map<ResourceType, int>.from(machine.inputBuffer);
            newInputs.update(ResourceType.ammunition, (v) => v + 1, ifAbsent: () => 1);
            nextMachineGrid[r][c] = machine.copyWith(inputBuffer: newInputs);
            claimedResources.add(backCoords);
          }
        } else if (isAssembler) {
          var currentMachineState = nextMachineGrid[r][c]!;
          final backCoords = _getCoordsForDirection(r, c, _getBackInputDirection(machine.direction));
          final resourceOnBelt = _getResourceAt(backCoords);

          if (resourceOnBelt != null && !claimedResources.contains(backCoords)) {
            bool canTake = false;
            // Check if it's an input for any of the available assembler recipes
            final availableRecipes = machine.type == MachineType.assembler ? assemblerRecipes : assemblerRecipesT2;
            for (final recipe in availableRecipes) {
              if (recipe.inputs.containsKey(resourceOnBelt)) {
                // For simplicity, let's use a generic buffer limit of 10 per item type.
                if ((currentMachineState.inputBuffer[resourceOnBelt] ?? 0) < 10) {
                  canTake = true;
                }
                break;
              }
            }

            if (canTake) {
              final newInputs = Map<ResourceType, int>.from(currentMachineState.inputBuffer);
              newInputs.update(resourceOnBelt, (v) => v + 1, ifAbsent: () => 1);
              nextMachineGrid[r][c] = currentMachineState.copyWith(inputBuffer: newInputs);
              claimedResources.add(backCoords);
            }
          }
        } else if (isRefinery) {
          // Refineries take fluid from the back
          final backCoords = _getCoordsForDirection(r, c, _getBackInputDirection(machine.direction));
          final pipe = _getPipeAt(backCoords);
          if (pipe != null) {
            if (pipe.fluid == ResourceType.crudeOil && pipe.fluidAmount > 0 && !claimedPipes.contains(backCoords)) {
              final currentMachineState = nextMachineGrid[r][c]!;
              final currentBuffer = currentMachineState.fluidInputBuffer[ResourceType.crudeOil] ?? 0;
              if (currentBuffer < 100) {
                final newInputs = Map<ResourceType, int>.from(currentMachineState.fluidInputBuffer);
                newInputs.update(ResourceType.crudeOil, (v) => v + pipe.fluidAmount, ifAbsent: () => pipe.fluidAmount);
                nextMachineGrid[r][c] = currentMachineState.copyWith(fluidInputBuffer: newInputs);
                claimedPipes.add(backCoords);
              }
            }
          }
        } else {
          // --- Other Machines: Single Input from Back ---
          final recipe = allRecipes[machine.type];
          final canTakeInput = (recipe?.inputs.isNotEmpty ?? false) ||
              machine.type == MachineType.storage ||
              machine.type == MachineType.grinder ||
              machine.type == MachineType.coalGenerator ||
              machine.type == MachineType.powerPole; // Poles don't take items, but this prevents errors

          if (canTakeInput) {
            final backCoords = _getCoordsForDirection(r, c, _getBackInputDirection(machine.direction));
            final resourceOnBelt = _getResourceAt(backCoords);

            if (resourceOnBelt != null && !claimedResources.contains(backCoords)) {
              if (machine.type == MachineType.coalGenerator) {
                if (resourceOnBelt == ResourceType.coal && (machine.inputBuffer[ResourceType.coal] ?? 0) < 10) {
                  final newInputs = Map<ResourceType, int>.from(machine.inputBuffer);
                  newInputs.update(ResourceType.coal, (v) => v + 1, ifAbsent: () => 1);
                  nextMachineGrid[r][c] = machine.copyWith(inputBuffer: newInputs);
                  claimedResources.add(backCoords);
                }
              } else if (machine.type == MachineType.grinder) {
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

    // --- Phase 1.5: Factory Core Intake ---
    if (nextFactoryCore != null && !nextFactoryCore.isComplete) {
      final core = nextFactoryCore;
      final currentPhaseRequirements = factoryCorePhaseRequirements[core.phase];
      final nextCoreProgress = Map<ResourceType, int>.from(core.progress);
      bool progressMade = false;

      // Check all tiles adjacent to the core's bounding box for feeding conveyors
      for (int rOffset = -1; rOffset <= factoryCoreSize; rOffset++) {
        for (int cOffset = -1; cOffset <= factoryCoreSize; cOffset++) {
          // Skip interior and corner tiles for this simple check
          if ((rOffset >= 0 && rOffset < factoryCoreSize) && (cOffset >= 0 && cOffset < factoryCoreSize)) continue;

          final checkR = core.row + rOffset;
          final checkC = core.col + cOffset;

          // Check if this tile is a conveyor pointing towards the core
          final conveyor = _getConveyorAt((checkR, checkC));
          if (conveyor == null || conveyor.resource == null) continue;

          final (nextR, nextC) = _getCoordsForDirection(checkR, checkC, conveyor.direction);

          // Is it pointing into the core's 3x3 bounding box?
          bool pointingIntoCore = nextR >= core.row && nextR < core.row + factoryCoreSize && nextC >= core.col && nextC < core.col + factoryCoreSize;

          if (pointingIntoCore && !claimedResources.contains((checkR, checkC))) {
            final resource = conveyor.resource!;
            if (currentPhaseRequirements.containsKey(resource)) {
              final needed = currentPhaseRequirements[resource]!;
              final have = nextCoreProgress[resource] ?? 0;
              if (have < needed) {
                nextCoreProgress.update(resource, (v) => v + 1, ifAbsent: () => 1);
                claimedResources.add((checkR, checkC));
                progressMade = true;
              }
            }
          }
        }
      }

      if (progressMade) {
        nextFactoryCore = core.copyWith(progress: nextCoreProgress);
        // Check for phase completion
        bool phaseComplete = true;
        for (final entry in currentPhaseRequirements.entries) {
          if ((nextCoreProgress[entry.key] ?? 0) < entry.value) {
            phaseComplete = false;
            break;
          }
        }

        if (phaseComplete) {
          final nextPhase = core.phase + 1;
          final isGameWon = nextPhase >= factoryCorePhaseRequirements.length;
          nextFactoryCore = nextFactoryCore.copyWith(phase: isGameWon ? core.phase : nextPhase, progress: {}, isComplete: isGameWon);
        }
      }
    }

    // --- Phase 1.7: Train Stop Loading/Unloading ---
    // For simplicity, train stops interact with adjacent storage containers.
    for (int r = 0; r < nextMachineGrid.length; r++) {
      for (int c = 0; c < nextMachineGrid[r].length; c++) {
        final machine = nextMachineGrid[r][c];
        if (machine?.type != MachineType.trainStop) continue;

        // Find a train at this stop
        final trainIndex = nextTrains.indexWhere((t) => t.locomotivePosition == (r, c));
        if (trainIndex == -1) continue;

        final train = nextTrains[trainIndex];
        final stopData = machine!.trainStopData!;

        // Find an adjacent storage container
        Machine? storage;
        for (final dir in Direction.values) {
          final (adjR, adjC) = _getCoordsForDirection(r, c, dir);
          final adjMachine = _getMachineAt((adjR, adjC));
          if (adjMachine?.type == MachineType.storage) {
            storage = adjMachine;
            break;
          }
        }
        if (storage == null) continue;

        if (stopData.mode == TrainStopMode.load && train.status == TrainStatus.waitingForLoad) {
          // Find first empty wagon or wagon with same resource type
          final wagonIndex = train.wagons.indexWhere((w) => w.amount < wagonCapacity && (w.resource == null || w.resource == storage!.configuredOutput));
          if (wagonIndex != -1 && storage.configuredOutput != null) {
            final resource = storage.configuredOutput!;
            if ((nextInventory[resource] ?? 0) > 0) {
              nextInventory.update(resource, (v) => v - 1);
              final newWagons = List<CargoWagon>.from(train.wagons);
              final oldWagon = newWagons[wagonIndex];
              newWagons[wagonIndex] = oldWagon.copyWith(resource: resource, amount: oldWagon.amount + 1);
              nextTrains[trainIndex] = train.copyWith(wagons: newWagons);
            }
          }
        } else if (stopData.mode == TrainStopMode.unload && train.status == TrainStatus.waitingForUnload) {
          // Find first wagon with items
          final wagonIndex = train.wagons.indexWhere((w) => w.amount > 0);
          if (wagonIndex != -1) {
            final wagon = train.wagons[wagonIndex];
            nextInventory.update(wagon.resource!, (v) => v + 1, ifAbsent: () => 1);
            final newWagons = List<CargoWagon>.from(train.wagons);
            newWagons[wagonIndex] = wagon.copyWith(amount: wagon.amount - 1);
            nextTrains[trainIndex] = train.copyWith(wagons: newWagons);
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
        // Machine must be powered to produce! (Generators don't produce via recipes, so they are exempt here)
        if (machine == null || !machine.isPowered) continue;

        // --- Production for machines with no inputs (Miners, Pumps, Derricks) ---
        if (allRecipes.containsKey(machine.type) && allRecipes[machine.type]!.inputs.isEmpty) {
          _handleResourceExtraction(r, c, machine, nextMachineGrid);
        }

        // --- Production for machines with inputs (Smelters, Assemblers, etc.) ---
        _handleRecipeProduction(r, c, machine, nextMachineGrid);
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

        // Solid items eject onto the tile in front of them.
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

    // --- Phase 4.5: Fluid Ejection ---
    for (int r = 0; r < nextMachineGrid.length; r++) {
      for (int c = 0; c < nextMachineGrid[r].length; c++) {
        final machine = nextMachineGrid[r][c];
        if (machine?.fluidOutputBuffer.isEmpty ?? true) continue;

        // Fluid items eject onto the tile in front of them.
        int ejectR = r, ejectC = c;
        switch (machine!.direction) {
          case Direction.up: ejectR--; break;
          case Direction.down: ejectR++; break;
          case Direction.left: ejectC--; break;
          case Direction.right: ejectC++; break;
        }

        // Check if the target tile is a valid pipe that can accept the fluid.
        final pipe = _getPipeAt((ejectR, ejectC));
        if (pipe != null) {
          if ((pipe.fluid == null || pipe.fluid == machine.fluidOutputBuffer.keys.first) && pipe.fluidAmount < pipeCapacity) {
            final fluidToEject = machine.fluidOutputBuffer.keys.first;
            final amountToEject = machine.fluidOutputBuffer.values.first;
            final newAmount = pipe.fluidAmount + amountToEject;
            if (newAmount <= pipeCapacity) {
              nextPipeGrid[ejectR][ejectC] = pipe.copyWith(fluid: fluidToEject, fluidAmount: newAmount);
              nextMachineGrid[r][c] = machine.copyWith(fluidOutputBuffer: {}); // Clears the buffer after ejection
            }
          }
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

    // --- Phase 5.2: Pipe Movement ---
    for (int r = 0; r < state.pipeGrid.length; r++) {
      for (int c = 0; c < state.pipeGrid[r].length; c++) {
        final pipe = state.pipeGrid[r][c];
        if (pipe != null && pipe.fluid != null && pipe.fluidAmount > 0 && !claimedPipes.contains((r, c)) && !movedPipes.contains((r, c))) {
          final (nextR, nextC) = _getCoordsForDirection(r, c, pipe.direction);
          final nextPipe = _getPipeAt((nextR, nextC)); // Check state grid for pipe existence
          if (nextPipe != null) {
            if ((nextPipe.fluid == null || nextPipe.fluid == pipe.fluid) && nextPipe.fluidAmount < pipeCapacity && !movedPipes.contains((nextR, nextC))) {
              final amountToMove = min(10, pipe.fluidAmount);
              final spaceInNext = pipeCapacity - nextPipe.fluidAmount;
              final actualMoveAmount = min(amountToMove, spaceInNext);
              if (actualMoveAmount > 0) {
                nextPipeGrid[nextR][nextC] = nextPipe.copyWith(fluid: pipe.fluid, fluidAmount: nextPipe.fluidAmount + actualMoveAmount);
                nextPipeGrid[r][c] = pipe.copyWith(fluidAmount: pipe.fluidAmount - actualMoveAmount);
                movedPipes.add((nextR, nextC));
              }
            }
          }
        }
      }
    }

    // --- Phase 5.5: Drone Exploration ---
    for (int r = 0; r < nextMachineGrid.length; r++) {
      for (int c = 0; c < nextMachineGrid[r].length; c++) {
        final machine = nextMachineGrid[r][c];
        if (machine?.type == MachineType.droneStation && machine!.droneStationData != null) {
          final newDrones = <Drone>[];
          bool changed = false;
          for (final drone in machine.droneStationData!.drones) {
            if (drone.status == DroneStatus.exploring) {
              final newTicks = drone.ticksRemaining - 1;
              if (newTicks <= 0) {
                // Drone has returned!
                final pointsGained = random.nextInt(50) + 25; // 25 to 74 points
                final resourceGained = [ResourceType.ironOre, ResourceType.copperOre, ResourceType.coal][random.nextInt(3)];
                final amountGained = random.nextInt(20) + 10; // 10 to 29 of a resource

                nextPoints += pointsGained;
                nextInventory.update(resourceGained, (v) => v + amountGained, ifAbsent: () => amountGained);

                state = state.copyWith(lastMessage: 'Drone returned! Gained $pointsGained points and $amountGained ${resourceGained.name}.');

                newDrones.add(drone.copyWith(status: DroneStatus.idle, ticksRemaining: 0));
                changed = true;
              } else {
                // Still exploring
                newDrones.add(drone.copyWith(ticksRemaining: newTicks));
              }
            } else {
              newDrones.add(drone);
            }
          }

          if (changed) {
            final newStationData = machine.droneStationData!.copyWith(drones: newDrones);
            nextMachineGrid[r][c] = machine.copyWith(droneStationData: newStationData);
          }
        }
      }
    }

    // --- Phase 5.7: Train Movement & Scheduling ---
    for (int i = 0; i < nextTrains.length; i++) {
      final train = nextTrains[i];
      if (train.schedule.isEmpty) continue;

      if (train.status == TrainStatus.movingToStation) {
        if (train.currentPath.isNotEmpty) {
          final nextPos = train.currentPath.first;
          final remainingPath = train.currentPath.sublist(1);
          nextTrains[i] = train.copyWith(locomotivePosition: nextPos, currentPath: remainingPath);
        } else {
          // Arrived at station
          final stop = _findStopByName(train.schedule[train.currentScheduleIndex].stationName);
          if (stop != null && stop.trainStopData != null) {
            final newStatus = stop.trainStopData!.mode == TrainStopMode.load ? TrainStatus.waitingForLoad : TrainStatus.waitingForUnload;
            nextTrains[i] = train.copyWith(status: newStatus, ticksToWait: 5); // Wait 5 seconds
          }
        }
      } else if (train.status == TrainStatus.idleAtStation || train.status == TrainStatus.waitingForLoad || train.status == TrainStatus.waitingForUnload) {
        // Check if waiting is done
        if (train.ticksToWait > 0) {
          nextTrains[i] = train.copyWith(ticksToWait: train.ticksToWait - 1);
        } else {
          // Depart to next station
          final nextScheduleIndex = (train.currentScheduleIndex + 1) % train.schedule.length;
          final nextStopName = train.schedule[nextScheduleIndex].stationName;
          final destinationStop = _findStopByName(nextStopName);

          if (destinationStop != null) {
            final path = _findPathOnRails(train.locomotivePosition, (destinationStop.row, destinationStop.col));
            if (path != null) {
              nextTrains[i] = train.copyWith(
                status: TrainStatus.movingToStation,
                currentScheduleIndex: nextScheduleIndex,
                currentPath: path,
              );
            }
          }
        }
      }
    }

    // --- Phase 5.8: Enemy Logic ---
    // Nests
    final newNests = <EnemyNest>[];
    for (final nest in nextEnemyNests) {
      if (nest.health <= 0) continue; // Skip dead nests

      var newCooldown = nest.spawnCooldown;
      if (state.pollutionGrid[nest.row][nest.col] > 50) {
        newCooldown = max(0, newCooldown - 1);
      }

      if (newCooldown <= 0) {
        // Spawn enemy
        final newEnemy = Enemy(id: nextEnemyId, position: (nest.col + 0.5, nest.row + 0.5));
        nextEnemies.add(newEnemy);
        nextEnemyId++;
        newCooldown = 10; // Reset cooldown
      }
      newNests.add(nest.copyWith(spawnCooldown: newCooldown));
    }
    nextEnemyNests = newNests;

    // Enemies
    final survivingEnemies = <Enemy>[];
    for (var enemy in nextEnemies) {
      if (enemy.health <= 0) continue; // Skip dead enemies

      if (enemy.path.isEmpty) {
        // Find a new target
        // TODO: Find path to nearest building
      } else {
        // Move along path
        // TODO: Implement movement
      }

      // Attack
      final (ex, ey) = enemy.position;
      final (er, ec) = (ey.floor(), ex.floor());
      // Check adjacent tiles for buildings to attack
      bool attacked = false;
      for (final dir in Direction.values) {
        final (ar, ac) = _getCoordsForDirection(er, ec, dir);
        final machineToAttack = _getMachineAt((ar, ac));
        if (machineToAttack != null) {
          final newHealth = machineToAttack.health - 5; // 5 damage
          nextMachineGrid[ar][ac] = machineToAttack.copyWith(health: newHealth);
          if (newHealth <= 0) {
            // TODO: Handle building destruction effects
            nextMachineGrid[ar][ac] = null;
          }
          attacked = true;
          break;
        }
      }
      survivingEnemies.add(enemy);
    }
    nextEnemies = survivingEnemies;

    // --- Phase 5.9: Turret Logic ---
    for (int r = 0; r < nextMachineGrid.length; r++) {
      for (int c = 0; c < nextMachineGrid[r].length; c++) {
        final machine = nextMachineGrid[r][c];
        if (machine?.type != MachineType.gunTurret) continue;

        // TODO: Turret firing logic
        // 1. Find nearest enemy in range
        // 2. If target found, has ammo, and cooldown is ready:
        // 3.   - Consume ammo
        // 4.   - Damage enemy
        // 5.   - Reset cooldown
      }
    }

    // --- Phase 6: Finalize State ---
    // Clear resources that were consumed by machine intake
    for (final coords in claimedResources) {
      final conveyor = nextConveyorGrid[coords.$1][coords.$2];
      if (conveyor != null) nextConveyorGrid[coords.$1][coords.$2] = conveyor.copyWith(clearResource: true);
    }

    for (final coords in claimedPipes) {
      final pipe = nextPipeGrid[coords.$1][coords.$2];
      if (pipe != null) nextPipeGrid[coords.$1][coords.$2] = pipe.copyWith(clearFluid: true);
    }

    state = state.copyWith(
      grid: nextMachineGrid,
      conveyorGrid: nextConveyorGrid,
      railGrid: state.railGrid, // Rail grid doesn't change during tick
      player: nextPlayer,
      pollutionGrid: nextPollutionGrid,
      enemyNests: nextEnemyNests,
      enemies: nextEnemies,
      inventory: nextInventory,
      pipeGrid: nextPipeGrid,
      powerCapacity: totalCapacity,
      powerDemand: totalDemand,
      points: nextPoints,
      factoryCore: nextFactoryCore,
      nextEnemyId: nextEnemyId,
      gameTick: state.gameTick + 1,
      trains: nextTrains,
    );
  }

  final Map<MachineType, MachineType> _upgradePaths = {
    MachineType.coalMiner: MachineType.coalMinerT2,
    MachineType.miner: MachineType.minerT2,
    MachineType.copperMiner: MachineType.copperMinerT2,
    MachineType.smelter: MachineType.smelterT2,
    MachineType.assembler: MachineType.assemblerT2,
  };

  /// Places a new machine on the grid, or upgrades an existing one.
  void placeMachine(MachineType type, int row, int col) {
    // 1. Check if the cell is within bounds.
    if (row < 0 || row >= state.grid.length || col < 0 || col >= state.grid[0].length) return;
    // 1.5 Check if player is close enough
    if (!_isWithinPlayerReach((row, col))) {
      state = state.copyWith(lastMessage: 'Too far away to build.');
      return;
    }

    final existingMachine = state.grid[row][col];

    // --- Handle In-Place Upgrades ---
    if (existingMachine != null) {
      final targetUpgradeType = _upgradePaths[existingMachine.type];
      if (targetUpgradeType == type) {
        // This is a valid upgrade attempt.
        final t1Cost = machineCosts[existingMachine.type] ?? {};
        final t2Cost = machineCosts[type] ?? {};
        final upgradeCost = <ResourceType, int>{};

        // Calculate the difference in cost
        t2Cost.forEach((resource, t2Amount) {
          final t1Amount = t1Cost[resource] ?? 0;
          if (t2Amount > t1Amount) {
            upgradeCost[resource] = t2Amount - t1Amount;
          }
        });

        if (_canAfford(upgradeCost, 'a ${type.name} upgrade')) {
          final newInventory = _deductCost(upgradeCost);
          final newGrid = state.grid.map((rowList) => List<Machine?>.from(rowList)).toList();
          // Preserve the state of the old machine (direction, buffers, etc.)
          newGrid[row][col] = existingMachine.copyWith(type: type);

          state = state.copyWith(
            grid: newGrid,
            inventory: newInventory,
            lastMessage: 'Upgraded ${existingMachine.type.name} to ${type.name}!',
          );
        }
        return; // End the function whether upgrade succeeded or failed
      }
      // If it's not a valid upgrade, do nothing and let the user know.
      state = state.copyWith(lastMessage: 'Cannot place machine here.');
      return;
    }

    // --- Handle Placing a New Machine on an empty tile ---
    final cost = machineCosts[type];
    if (cost == null || !_canAfford(cost, 'a ${type.name}')) return;

    // Special check for power pole
    if (type == MachineType.powerPole && !state.unlockedResearch.contains(ResearchType.copperProcessing)) {
      state = state.copyWith(lastMessage: 'Cannot build Power Pole without Copper Processing for wires.');
      return;
    }
    if (type == MachineType.trainStop && _getRailAt(row, col) == null) {
      state = state.copyWith(lastMessage: 'Train Stops must be placed on rails.');
      return;
    }
    if ((type == MachineType.wall || type == MachineType.gunTurret) && !state.unlockedResearch.contains(ResearchType.military)) {
      state = state.copyWith(lastMessage: 'Requires Military research.');
      return;
    }
    final newInventory = _deductCost(cost);

    var newMachine = Machine(type: type, row: row, col: col);
    if (type == MachineType.droneStation) {
      newMachine = newMachine.copyWith(droneStationData: const DroneStationData());
    }
    if (type == MachineType.trainStop) {
      newMachine = newMachine.copyWith(trainStopData: const TrainStopData());
    }
    if (type == MachineType.gunTurret) {
      newMachine = newMachine.copyWith(turretData: const TurretData());
    }
    final newGrid = state.grid.map((rowList) => List<Machine?>.from(rowList)).toList();
    newGrid[row][col] = newMachine;

    state = state.copyWith(
      grid: newGrid,
      inventory: newInventory,
    );
  }

  /// Places the Factory Core on the grid.
  void placeFactoryCore(int row, int col) {
    // 1. Check if the 3x3 area is within bounds and empty.
    if (row < 0 || row + factoryCoreSize > state.grid.length || col < 0 || col + factoryCoreSize > state.grid[0].length) return;
    // 1.5 Check reach
    if (!_isWithinPlayerReach((row + 1, col + 1))) {
      state = state.copyWith(lastMessage: 'Too far away to build the Factory Core.');
      return;
    }

    for (int r = row; r < row + factoryCoreSize; r++) {
      for (int c = col; c < col + factoryCoreSize; c++) {
        if (state.grid[r][c] != null || state.conveyorGrid[r][c] != null) {
          state = state.copyWith(lastMessage: 'Area is not clear to build the Factory Core.');
          return;
        }
      }
    }

    // 2. Check if the player can afford it.
    if (!_canAfford(factoryCorePlacementCost, 'the Factory Core')) return;

    // 3. Create the new state components.
    final newInventory = _deductCost(factoryCorePlacementCost);
    final newCore = FactoryCoreState(row: row, col: col);

    // 4. Update the state.
    state = state.copyWith(factoryCore: newCore, inventory: newInventory);
  }

  /// Removes a machine from the grid.
  void removeMachine(int row, int col) {
    if (row < 0 || row >= state.grid.length || col < 0 || col >= state.grid[0].length) return;
    if (state.grid[row][col] == null) return;
    // Check reach
    if (!_isWithinPlayerReach((row, col))) {
      state = state.copyWith(lastMessage: 'Too far away to demolish.');
      return;
    }

    final newGrid = state.grid.map((rowList) => List<Machine?>.from(rowList)).toList();
    newGrid[row][col] = null;

    state = state.copyWith(grid: newGrid);
  }

  /// Places a new conveyor on the grid.
  void placeConveyor(Direction direction, int row, int col) {
    if (row < 0 || row >= state.conveyorGrid.length || col < 0 || col >= state.conveyorGrid[0].length) return;
    if (state.conveyorGrid[row][col] != null) return;
    // Check reach
    if (!_isWithinPlayerReach((row, col))) {
      state = state.copyWith(lastMessage: 'Too far away to build.');
      return;
    }

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
    // Check reach
    if (!_isWithinPlayerReach((row, col))) {
      state = state.copyWith(lastMessage: 'Too far away to build.');
      return;
    }

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
    // Check reach
    if (!_isWithinPlayerReach((row, col))) {
      state = state.copyWith(lastMessage: 'Too far away to build.');
      return;
    }

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
    // Check reach
    if (!_isWithinPlayerReach((row, col))) {
      state = state.copyWith(lastMessage: 'Too far away to demolish.');
      return;
    }

    final newGrid = state.conveyorGrid.map((rowList) => List<Conveyor?>.from(rowList)).toList();
    newGrid[row][col] = null;

    state = state.copyWith(conveyorGrid: newGrid);
  }

  /// Places a new pipe on the grid.
  void placePipe(Direction direction, int row, int col) {
    if (row < 0 || row >= state.pipeGrid.length || col < 0 || col >= state.pipeGrid[0].length) return;
    if (state.pipeGrid[row][col] != null) return;
    // Check reach
    if (!_isWithinPlayerReach((row, col))) {
      state = state.copyWith(lastMessage: 'Too far away to build.');
      return;
    }

    // 2. Check if player can afford it.
    if (!_canAfford(pipeCost, 'a pipe')) return;

    // 3. Create new state components.
    final newInventory = _deductCost(pipeCost);

    final newPipe = Pipe(direction: direction, row: row, col: col);
    final newGrid = state.pipeGrid.map((rowList) => List<Pipe?>.from(rowList)).toList();
    newGrid[row][col] = newPipe;

    // 4. Update state.
    state = state.copyWith(pipeGrid: newGrid, inventory: newInventory);
  }

  /// Removes a pipe from the grid.
  void removePipe(int row, int col) {
    if (row < 0 || row >= state.pipeGrid.length || col < 0 || col >= state.pipeGrid[0].length) return;
    if (state.pipeGrid[row][col] == null) return;
    // Check reach
    if (!_isWithinPlayerReach((row, col))) {
      state = state.copyWith(lastMessage: 'Too far away to demolish.');
      return;
    }
    final newGrid = state.pipeGrid.map((rowList) => List<Pipe?>.from(rowList)).toList();
    newGrid[row][col] = null;
    state = state.copyWith(pipeGrid: newGrid);
  }

  /// Places a new rail on the grid.
  void placeRail(int row, int col) {
    if (row < 0 || row >= state.railGrid.length || col < 0 || col >= state.railGrid[0].length) return;
    if (state.railGrid[row][col] != null) return;
    // Check reach
    if (!_isWithinPlayerReach((row, col))) {
      state = state.copyWith(lastMessage: 'Too far away to build.');
      return;
    }
    if (!_canAfford(railCost, 'a rail')) return;

    final newInventory = _deductCost(railCost);
    final newRail = Rail(row: row, col: col);
    final newGrid = state.railGrid.map((rowList) => List<Rail?>.from(rowList)).toList();
    newGrid[row][col] = newRail;
    state = state.copyWith(railGrid: newGrid, inventory: newInventory);
  }

  /// Removes a rail from the grid.
  void removeRail(int row, int col) {
    if (row < 0 || row >= state.railGrid.length || col < 0 || col >= state.railGrid[0].length) return;
    if (state.railGrid[row][col] == null) return;
    // Check reach
    if (!_isWithinPlayerReach((row, col))) {
      state = state.copyWith(lastMessage: 'Too far away to demolish.');
      return;
    }
    final newGrid = state.railGrid.map((rowList) => List<Rail?>.from(rowList)).toList();
    newGrid[row][col] = null;
    state = state.copyWith(railGrid: newGrid);
  }

  /// Rotates an existing conveyor on the grid.
  void rotateConveyor(int row, int col) {
    final conveyor = state.conveyorGrid[row][col];
    if (conveyor == null) return; // Can't rotate something that isn't there.
    // Check reach
    if (!_isWithinPlayerReach((row, col))) {
      state = state.copyWith(lastMessage: 'Too far away to rotate.');
      return;
    }

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
    // Check reach
    if (!_isWithinPlayerReach((row, col))) {
      state = state.copyWith(lastMessage: 'Too far away to rotate.');
      return;
    }

    // Cycle through the directions
    final currentDirectionIndex = Direction.values.indexOf(machine.direction);
    final nextDirectionIndex = (currentDirectionIndex + 1) % Direction.values.length;
    final nextDirection = Direction.values[nextDirectionIndex];

    final newGrid = state.grid.map((rowList) => List<Machine?>.from(rowList)).toList();
    newGrid[row][col] = machine.copyWith(direction: nextDirection);

    state = state.copyWith(grid: newGrid);
  }

  /// Sets the output resource for a storage container.
  void setStorageOutput(int row, int col, ResourceType? newOutput) {
    final machine = state.grid[row][col];
    if (machine == null || machine.type != MachineType.storage) return;

    final newGrid = state.grid.map((rowList) => List<Machine?>.from(rowList)).toList();
    newGrid[row][col] = machine.copyWith(configuredOutput: newOutput);

    state = state.copyWith(
      grid: newGrid,
      lastMessage: 'Storage set to output: ${newOutput?.name ?? 'Nothing'}',
    );
  }

  /// Sets the name for a train stop.
  void setTrainStopName(int row, int col, String name) {
    final machine = state.grid[row][col];
    if (machine?.type != MachineType.trainStop || machine!.trainStopData == null) return;

    final newGrid = state.grid.map((rowList) => List<Machine?>.from(rowList)).toList();
    newGrid[row][col] = machine.copyWith(trainStopData: machine.trainStopData!.copyWith(stationName: name));

    state = state.copyWith(
      grid: newGrid,
      lastMessage: 'Train Stop renamed to "$name".',
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

  /// Unlocks a research item if the player has enough points and meets prerequisites.
  void unlockResearch(ResearchType type) {
    final research = allResearch[type];
    if (research == null) return;

    // 1. Check if already unlocked
    if (state.unlockedResearch.contains(type)) {
      state = state.copyWith(lastMessage: 'Already researched ${research.name}.');
      return;
    }

    // 2. Check for prerequisites
    if (!state.unlockedResearch.containsAll(research.prerequisites)) {
      state = state.copyWith(lastMessage: 'Missing prerequisites for ${research.name}.');
      return;
    }

    // 3. Check cost
    if (state.points < research.cost) {
      state = state.copyWith(lastMessage: 'Not enough points to research ${research.name}.');
      return;
    }

    // 4. Unlock it
    final newPoints = state.points - research.cost;
    final newUnlocked = Set<ResearchType>.from(state.unlockedResearch)..add(type);

    // --- Handle specific research effects ---
    var nextMachineGrid = state.grid;
    var nextConveyorGrid = state.conveyorGrid;
    var nextPipeGrid = state.pipeGrid;
    var nextRailGrid = state.railGrid;
    var nextPollutionGrid = state.pollutionGrid;
    var nextResourceGrid = state.resourceGrid;

    if (type == ResearchType.landExpansion) {
      final currentHeight = state.grid.length;
      final currentWidth = state.grid.isNotEmpty ? state.grid[0].length : 0;
      final newHeight = currentHeight + 5;
      final newWidth = currentWidth + 5;

      // Create new larger grids, initialized with nulls
      final expandedMachineGrid = List.generate(newHeight, (_) => List<Machine?>.filled(newWidth, null));
      final expandedConveyorGrid = List.generate(newHeight, (_) => List<Conveyor?>.filled(newWidth, null));
      final expandedPipeGrid = List.generate(newHeight, (_) => List<Pipe?>.filled(newWidth, null));
      final expandedRailGrid = List.generate(newHeight, (_) => List<Rail?>.filled(newWidth, null));
      final expandedPollutionGrid = List.generate(newHeight, (_) => List<int>.filled(newWidth, 0));
      final expandedResourceGrid = List.generate(newHeight, (_) => List<ResourceType?>.filled(newWidth, null));

      // Copy old data
      for (int r = 0; r < currentHeight; r++) {
        for (int c = 0; c < currentWidth; c++) {
          expandedMachineGrid[r][c] = state.grid[r][c];
          expandedConveyorGrid[r][c] = state.conveyorGrid[r][c];
          expandedPipeGrid[r][c] = state.pipeGrid[r][c];
          expandedRailGrid[r][c] = state.railGrid[r][c];
          expandedPollutionGrid[r][c] = state.pollutionGrid[r][c];
          expandedResourceGrid[r][c] = state.resourceGrid[r][c];
        }
      }

      // Generate resources in the new area
      final random = Random();
      for (int r = 0; r < newHeight; r++) {
        for (int c = 0; c < newWidth; c++) {
          if (r >= currentHeight || c >= currentWidth) {
            // This is a new tile, generate a resource patch
            final val = random.nextDouble();
            if (val < 0.05) expandedResourceGrid[r][c] = ResourceType.ironOre;
            else if (val < 0.1) expandedResourceGrid[r][c] = ResourceType.copperOre;
            else if (val < 0.15) expandedResourceGrid[r][c] = ResourceType.coal;
          }
        }
      }

      nextMachineGrid = expandedMachineGrid;
      nextConveyorGrid = expandedConveyorGrid;
      nextPipeGrid = expandedPipeGrid;
      nextRailGrid = expandedRailGrid;
      nextPollutionGrid = expandedPollutionGrid;
      nextResourceGrid = expandedResourceGrid;
    }

    state = state.copyWith(
      points: newPoints,
      unlockedResearch: newUnlocked,
      lastMessage: 'Unlocked: ${research.name}!',
      grid: nextMachineGrid,
      conveyorGrid: nextConveyorGrid,
      pipeGrid: nextPipeGrid,
      railGrid: nextRailGrid,
      pollutionGrid: nextPollutionGrid,
      resourceGrid: nextResourceGrid,
    );
  }

  /// Creates a new train on a rail tile.
  void createTrain(int row, int col) {
    if (_getRailAt(row, col) == null) return;
    final newId = state.trains.length;
    final newTrain = Train(id: newId, locomotivePosition: (row, col));
    state = state.copyWith(trains: [...state.trains, newTrain]);
  }

  /// Moves the player character.
  void movePlayer(Direction direction) {
    int moveSpeed = 1;
    if (state.player.equipment.contains(ResourceType.exoskeletonLegs)) {
      moveSpeed = 2;
    }

    var (c, r) = state.player.position;

    for (int i = 0; i < moveSpeed; i++) {
      var (nextC, nextR) = (c, r);
      switch (direction) {
        case Direction.up: nextR--; break;
        case Direction.down: nextR++; break;
        case Direction.left: nextC--; break;
        case Direction.right: nextC++; break;
      }

      // Check bounds
      if (nextR < 0 || nextR >= state.grid.length || nextC < 0 || nextC >= state.grid[0].length) continue;

      // Check for collision with machines
      if (state.grid[nextR][nextC] != null) continue;

      (c, r) = (nextC, nextR);
    }

    state = state.copyWith(player: state.player.copyWith(position: (c, r)));
  }

  /// Adds a recipe to the player's hand-crafting queue.
  void handCraft(Recipe recipe) {
    if (state.player.craftingQueue.length >= 5) {
      state = state.copyWith(lastMessage: 'Crafting queue is full.');
      return;
    }

    if (_canAfford(recipe.inputs, 'to hand-craft ${recipe.outputs.keys.first.name}')) {
      final newInventory = _deductCost(recipe.inputs);
      final newQueue = List<Recipe>.from(state.player.craftingQueue)..add(recipe);
      state = state.copyWith(
        inventory: newInventory,
        player: state.player.copyWith(craftingQueue: newQueue),
      );
    }
  }

  /// Builds a new drone at the specified station.
  void createDrone(int stationRow, int stationCol) {
    final machine = state.grid[stationRow][stationCol];
    if (machine?.type != MachineType.droneStation) return;

    if (_canAfford(droneCost, 'a Drone')) {
      final newInventory = _deductCost(droneCost);
      final newGrid = state.grid.map((rowList) => List<Machine?>.from(rowList)).toList();

      final stationData = machine!.droneStationData ?? const DroneStationData();
      final newDrones = List<Drone>.from(stationData.drones)..add(const Drone());

      newGrid[stationRow][stationCol] = machine.copyWith(droneStationData: stationData.copyWith(drones: newDrones));

      state = state.copyWith(grid: newGrid, inventory: newInventory, lastMessage: 'Drone constructed.');
    }
  }

  /// Sends a drone from a station on an exploration mission.
  void sendDroneToExplore(int stationRow, int stationCol, int droneIndex) {
    final machine = state.grid[stationRow][stationCol];
    if (machine?.type != MachineType.droneStation || machine!.droneStationData == null) return;

    final stationData = machine.droneStationData!;
    if (droneIndex < 0 || droneIndex >= stationData.drones.length) return;

    final drone = stationData.drones[droneIndex];
    if (drone.status == DroneStatus.idle) {
      final newGrid = state.grid.map((rowList) => List<Machine?>.from(rowList)).toList();
      final newDrones = List<Drone>.from(stationData.drones);
      newDrones[droneIndex] = drone.copyWith(status: DroneStatus.exploring, ticksRemaining: 60);

      newGrid[stationRow][stationCol] = machine.copyWith(droneStationData: stationData.copyWith(drones: newDrones));

      state = state.copyWith(grid: newGrid, lastMessage: 'Drone dispatched for exploration.');
    } else {
      state = state.copyWith(lastMessage: 'Drone is already exploring.');
    }
  }

  // --- Private Helper Methods ---

  bool _isWithinPlayerReach((int, int) coords) {
    const reach = 5;
    final (playerC, playerR) = state.player.position;
    final distance = (playerR - coords.$1).abs() + (playerC - coords.$2).abs();
    return distance <= reach;
  }

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

  Rail? _getRailAt(int r, int c) {
    if (r >= 0 && r < state.railGrid.length && c >= 0 && c < state.railGrid[0].length) {
      return state.railGrid[r][c];
    }
    return null;
  }

  Pipe? _getPipeAt((int, int) coords) {
    final r = coords.$1;
    final c = coords.$2;
    if (r >= 0 && r < state.pipeGrid.length && c >= 0 && c < state.pipeGrid[0].length) {
      return state.pipeGrid[r][c];
    }
    return null;
  }

  Conveyor? _getConveyorAt((int, int) coords) {
    final r = coords.$1;
    final c = coords.$2;
    if (r >= 0 && r < state.conveyorGrid.length && c >= 0 && c < state.conveyorGrid[0].length) {
      return state.conveyorGrid[r][c];
    }
    return null;
  }

  Machine? _getMachineAt((int, int) coords) {
    final r = coords.$1;
    final c = coords.$2;
    if (r >= 0 && r < state.grid.length && c >= 0 && c < state.grid[0].length) {
      return state.grid[r][c];
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

  List<Recipe> _getRecipesForMachine(MachineType type) {
    switch (type) {
      case MachineType.smelter:
        return smelterRecipes;
      case MachineType.smelterT2:
        return smelterRecipesT2;
      case MachineType.assembler:
        return assemblerRecipes;
      case MachineType.refinery:
        return refineryRecipes;
      case MachineType.chemicalPlant:
        return chemicalPlantRecipes;
      case MachineType.assemblerT2:
        return assemblerRecipesT2;
      default:
        return [];
    }
  }

  void _handleResourceExtraction(int r, int c, Machine machine, List<List<Machine?>> nextMachineGrid) {
    if (machine.outputBuffer != null || machine.fluidOutputBuffer.isNotEmpty) return;

    final recipe = allRecipes[machine.type]!;
    final producedResource = recipe.outputs.keys.first;
    final tileResource = state.resourceGrid[r][c];

    bool canMine = false;
    if (machine.type == MachineType.oilDerrick && tileResource == ResourceType.oilSeep) {
      canMine = true;
    } else if (machine.type == MachineType.offshorePump && tileResource == ResourceType.water) {
      canMine = true;
    } else if (producedResource == tileResource) {
      canMine = true;
    }

    if (canMine) {
      int newProgress = machine.productionProgress + 1;
      if (newProgress >= recipe.productionTime) {
        newProgress = 0;
        final outputAmount = recipe.outputs.values.first;
        if (producedResource.isFluid) {
          nextMachineGrid[r][c] = machine.copyWith(
            productionProgress: newProgress,
            fluidOutputBuffer: {producedResource: outputAmount},
          );
        } else {
          nextMachineGrid[r][c] = machine.copyWith(
            productionProgress: newProgress,
            outputBuffer: producedResource,
          );
        }
      } else {
        nextMachineGrid[r][c] = machine.copyWith(productionProgress: newProgress);
      }
    }
  }

  void _handleRecipeProduction(int r, int c, Machine machine, List<List<Machine?>> nextMachineGrid) {
    final possibleRecipes = _getRecipesForMachine(machine.type);
    if (possibleRecipes.isEmpty || machine.outputBuffer != null || machine.fluidOutputBuffer.isNotEmpty) return;

    if (machine.productionProgress == 0) {
      // --- Try to start a new production ---
      for (int i = 0; i < possibleRecipes.length; i++) {
        final recipeToTry = possibleRecipes[i];
        if (_canProduceRecipe(recipeToTry, machine)) {
          final newInputBuffer = _consumeSolidInputs(recipeToTry, machine);
          final newFluidInputBuffer = _consumeFluidInputs(recipeToTry, machine);
          final newProgress = (i * 1000) + 1;
          nextMachineGrid[r][c] = machine.copyWith(inputBuffer: newInputBuffer, fluidInputBuffer: newFluidInputBuffer, productionProgress: newProgress);
          return; // Start producing and exit
        }
      }
    } else {
      // --- Continue existing production ---
      final recipeIndex = machine.productionProgress ~/ 1000;
      final currentProgress = machine.productionProgress % 1000;

      if (recipeIndex < possibleRecipes.length) {
        final activeRecipe = possibleRecipes[recipeIndex];
        final newProgress = currentProgress + 1;

        if (newProgress >= activeRecipe.productionTime) {
          final outputResource = activeRecipe.outputs.keys.first;
          final outputAmount = activeRecipe.outputs.values.first;
          if (outputResource.isFluid) {
            nextMachineGrid[r][c] = machine.copyWith(productionProgress: 0, fluidOutputBuffer: {outputResource: outputAmount});
          } else {
            nextMachineGrid[r][c] = machine.copyWith(productionProgress: 0, outputBuffer: outputResource);
          }
        } else {
          nextMachineGrid[r][c] = machine.copyWith(productionProgress: (recipeIndex * 1000) + newProgress);
        }
      } else {
        nextMachineGrid[r][c] = machine.copyWith(productionProgress: 0);
      }
    }
  }

  bool _canProduceRecipe(Recipe recipe, Machine machine) {
    bool canProduce = true;
    for (final entry in recipe.inputs.entries) {
      if (entry.key.isFluid) {
        if ((machine.fluidInputBuffer[entry.key] ?? 0) < entry.value) canProduce = false;
      } else {
        if ((machine.inputBuffer[entry.key] ?? 0) < entry.value) canProduce = false;
      }
    }
    return canProduce;
  }

  Map<ResourceType, int> _consumeSolidInputs(Recipe recipe, Machine machine) {
    final newInputs = Map<ResourceType, int>.from(machine.inputBuffer);
    recipe.inputs.forEach((key, value) {if (!key.isFluid) newInputs.update(key, (v) => v - value);});
    return newInputs;
  }

  Map<ResourceType, int> _consumeFluidInputs(Recipe recipe, Machine machine) {
    final newInputs = Map<ResourceType, int>.from(machine.fluidInputBuffer);
    recipe.inputs.forEach((key, value) {if (key.isFluid) newInputs.update(key, (v) => v - value);});
    return newInputs;
  }

  Machine? _findStopByName(String name) {
    for (final row in state.grid) {
      for (final machine in row) {
        if (machine != null && machine.type == MachineType.trainStop && machine.trainStopData?.stationName == name) {
          return machine;
        }
      }
    }
    return null;
  }

  /// Finds a path between two points on the rail network using Breadth-First Search.
  List<(int, int)>? _findPathOnRails((int, int) start, (int, int) end) {
    final queue = <(int, int)>[start];
    final visited = {start};
    // A map to reconstruct the path: key is a node, value is the node that led to it.
    final cameFrom = <(int, int), (int, int)>{};

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);

      if (current == end) {
        // Path found, reconstruct it.
        final path = <(int, int)>[];
        var step = end;
        while (step != start) {
          path.insert(0, step);
          step = cameFrom[step]!;
        }
        return path;
      }

      // Check neighbors (up, down, left, right)
      for (final dir in Direction.values) {
        final neighbor = _getCoordsForDirection(current.$1, current.$2, dir);
        if (!visited.contains(neighbor) && _getRailAt(neighbor.$1, neighbor.$2) != null) {
          visited.add(neighbor);
          cameFrom[neighbor] = current;
          queue.add(neighbor);
        }
      }
    }

    // No path found
    return null;
  }
}