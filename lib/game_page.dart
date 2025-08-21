import 'package:factory_sim/ctrl/game_controller.dart';
import 'package:factory_sim/models/recipe.dart';
import 'package:factory_sim/models/research.dart';
import 'package:factory_sim/models/building_data.dart';
import 'package:factory_sim/models/factory_core.dart';
import 'package:factory_sim/models/conveyor.dart';
import 'package:factory_sim/models/tool.dart';
import 'package:factory_sim/models/pipe.dart';
import 'package:factory_sim/models/drone.dart';
import 'package:factory_sim/models/machine.dart';
import 'package:factory_sim/models/resource.dart';
import 'package:flutter/material.dart';
import 'package:factory_sim/models/enemy.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import 'models/rail.dart';
import 'models/train.dart';

class GamePage extends ConsumerWidget {
  const GamePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Listen for messages from the controller and show a SnackBar.
    ref.listen(gameControllerProvider.select((s) => s.lastMessage), (_, next) {
      if (next != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next),
            duration: const Duration(seconds: 3),
          ),
        );
        // Clear the message after showing it to prevent it from re-appearing.
        ref.read(gameControllerProvider.notifier).clearUserMessage();
      }
    });

    ref.listen(gameControllerProvider.select((s) => s.factoryCore?.isComplete), (_, next) {
      if (next == true) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Congratulations! You have completed the Factory Core!'),
          duration: Duration(seconds: 10),
        ));
      }
    });
    final gameState = ref.watch(gameControllerProvider);
    final gameController = ref.read(gameControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Factory Simulator'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Center(child: Text('Tick: ${gameState.gameTick}')),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Center(child: Text('Points: ${gameState.points}')),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Center(child: Text('Power: ${gameState.powerDemand} / ${gameState.powerCapacity} MW')),
          ),
        ],
      ),
      body: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.keyW) {
              gameController.movePlayer(Direction.up);
            } else if (event.logicalKey == LogicalKeyboardKey.keyS) {
              gameController.movePlayer(Direction.down);
            } else if (event.logicalKey == LogicalKeyboardKey.keyA) {
              gameController.movePlayer(Direction.left);
            } else if (event.logicalKey == LogicalKeyboardKey.keyD) {
              gameController.movePlayer(Direction.right);
            }
          }
          return KeyEventResult.handled;
        },
        child: Row(
          children: [
            // Game Grid
            Expanded(
              flex: 3,
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: gameState.grid.isNotEmpty ? gameState.grid[0].length : 1,
                ),
                itemCount: gameState.grid.length * (gameState.grid.isNotEmpty ? gameState.grid[0].length : 0),
                itemBuilder: (context, index) {
                  final row = index ~/ (gameState.grid.isNotEmpty ? gameState.grid[0].length : 1);
                  final col = index % (gameState.grid.isNotEmpty ? gameState.grid[0].length : 1);
                  final rail = gameState.railGrid[row][col];
                  final pipe = gameState.pipeGrid[row][col];
                  final pollution = gameState.pollutionGrid[row][col];
                  final nest = gameState.enemyNests.where((n) => n.row == row && n.col == col).firstOrNull;

                  final machine = gameState.grid[row][col];
                  final conveyor = gameState.conveyorGrid[row][col];
                  final train = gameState.trains.where((t) => t.locomotivePosition == (row, col)).firstOrNull;
                  final isPlayerHere = gameState.player.position == (col, row);

                  final core = gameState.factoryCore;
                  bool isPartOfCore = false;
                  int? corePartRow, corePartCol;
                  if (core != null &&
                      row >= core.row &&
                      row < core.row + factoryCoreSize &&
                      col >= core.col &&
                      col < core.col + factoryCoreSize) {
                    isPartOfCore = true;
                    corePartRow = row - core.row;
                    corePartCol = col - core.col;
                  }
                  return GestureDetector(
                    onTap: () {
                      switch (gameState.selectedTool) {
                        case Tool.coalMiner:
                        case Tool.miner:
                        case Tool.copperMiner:
                        case Tool.coalGenerator:
                        case Tool.offshorePump:
                        case Tool.oilDerrick:
                        case Tool.powerPole:
                        case Tool.smelter:
                        case Tool.refinery:
                        case Tool.chemicalPlant:
                        case Tool.assembler:
                        case Tool.wall:
                        case Tool.gunTurret:
                        case Tool.droneStation:
                        case Tool.trainStop:
                        case Tool.storage:
                        case Tool.grinder:
                        case Tool.coalMinerT2:
                        case Tool.minerT2:
                        case Tool.smelterT2:
                        case Tool.copperMinerT2:
                        case Tool.assemblerT2:
                          const toolToMachine = {
                            Tool.coalMiner: MachineType.coalMiner,
                            Tool.miner: MachineType.miner,
                            Tool.copperMiner: MachineType.copperMiner,
                            Tool.coalGenerator: MachineType.coalGenerator,
                            Tool.offshorePump: MachineType.offshorePump,
                            Tool.oilDerrick: MachineType.oilDerrick,
                            Tool.powerPole: MachineType.powerPole,
                            Tool.smelter: MachineType.smelter,
                            Tool.refinery: MachineType.refinery,
                            Tool.chemicalPlant: MachineType.chemicalPlant,
                            Tool.assembler: MachineType.assembler,
                            Tool.wall: MachineType.wall,
                            Tool.gunTurret: MachineType.gunTurret,
                            Tool.droneStation: MachineType.droneStation,
                            Tool.trainStop: MachineType.trainStop,
                            Tool.storage: MachineType.storage,
                            Tool.grinder: MachineType.grinder,
                            Tool.coalMinerT2: MachineType.coalMinerT2,
                            Tool.minerT2: MachineType.minerT2,
                            Tool.smelterT2: MachineType.smelterT2,
                            Tool.copperMinerT2: MachineType.copperMinerT2,
                            Tool.assemblerT2: MachineType.assemblerT2,
                          };
                          final typeToPlace = toolToMachine[gameState.selectedTool];
                          if (typeToPlace != null) {
                            if (machine != null && machine.type == typeToPlace) {
                              gameController.rotateMachine(row, col);
                            } else {
                              // This will handle both placing on empty and upgrading
                              gameController.placeMachine(typeToPlace, row, col);
                            }
                          }
                          break;
                        case Tool.conveyor:
                          // If a conveyor is already here, rotate it. Otherwise, place a new one.
                          if (conveyor != null) {
                            gameController.rotateConveyor(row, col);
                          } else {
                            // Place a new conveyor, defaulting to down.
                            gameController.placeConveyor(Direction.down, row, col);
                          }
                          break;
                        case Tool.pipe:
                          if (pipe != null) {
                            // gameController.rotatePipe(row, col); // TODO: Implement rotation if needed
                          } else {
                            // Place a new pipe, defaulting to down.
                            gameController.placePipe(Direction.down, row, col);
                          }
                          break;
                        case Tool.rail:
                          if (rail == null) {
                            gameController.placeRail(row, col);
                          } else if (train == null) {
                            gameController.createTrain(row, col);
                          }
                          break;
                        case Tool.splitter:
                          // If a conveyor/splitter is already here, rotate it. Otherwise, place a new one.
                          if (conveyor != null) {
                            gameController.rotateConveyor(row, col);
                          } else {
                            // Place a new splitter, defaulting to down.
                            gameController.placeSplitter(Direction.down, row, col);
                          }
                          break;
                        case Tool.merger:
                          // If a conveyor/merger is already here, rotate it. Otherwise, place a new one.
                          if (conveyor != null) {
                            gameController.rotateConveyor(row, col);
                          } else {
                            // Place a new merger, defaulting to down.
                            gameController.placeMerger(Direction.down, row, col);
                          }
                          break;
                        case Tool.factoryCore:
                          gameController.placeFactoryCore(row, col);
                          break;
                        case Tool.demolish:
                          gameController.removeMachine(row, col);
                          gameController.removeConveyor(row, col);
                          gameController.removePipe(row, col);
                          gameController.removeRail(row, col);
                          break;
                        case Tool.inspect:
                          if (machine?.type == MachineType.storage) {
                            _showStorageOutputDialog(context, ref, row, col);
                          } else if (machine?.type == MachineType.droneStation) {
                            _showDroneStationDialog(context, ref, row, col);
                          } else if (machine?.type == MachineType.trainStop) {
                            _showTrainStopDialog(context, ref, row, col);
                          }
                          break;
                      }
                    },
                    child: GridTileWidget(
                      machine: machine,
                      pipe: pipe,
                      rail: rail,
                      train: train,
                      nest: nest,
                      pollution: pollution,
                      isPlayerHere: isPlayerHere,
                      enemiesOnTile: gameState.enemies.where((e) => e.position.$1.floor() == col && e.position.$2.floor() == row).toList(),
                      conveyor: conveyor,
                      isPartOfCore: isPartOfCore,
                      corePartRow: corePartRow,
                      corePartCol: corePartCol,
                      factoryCoreState: core,
                      resourceOnTile: gameState.resourceGrid[row][col],
                    ),
                  );
                },
              ),
            ),
            // Control Panel
            Expanded(
              flex: 1,
              child: DefaultTabController(
                length: 4,
                child: Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Column(
                    children: [
                      const TabBar(
                        tabs: [
                          Tab(icon: Icon(Icons.person), text: 'Character'),
                          Tab(icon: Icon(Icons.build), text: 'Build'),
                          Tab(icon: Icon(Icons.science), text: 'Research'),
                          Tab(icon: Icon(Icons.hub), text: 'Core'),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            _CharacterPanel(),
                            _BuildPanel(),
                            _ResearchPanel(),
                            _CorePanel(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDroneStationDialog(BuildContext context, WidgetRef ref, int row, int col) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        // Use a Consumer here to rebuild the dialog content when the state changes
        return Consumer(
          builder: (context, widgetRef, child) {
            final machine = widgetRef.watch(gameControllerProvider.select((s) => s.grid[row][col]));
            final controller = widgetRef.read(gameControllerProvider.notifier);
            final drones = machine?.droneStationData?.drones ?? [];

            return AlertDialog(
              title: const Text('Drone Station'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (drones.isEmpty) const Text('No drones available. Build one!'),
                    for (int i = 0; i < drones.length; i++)
                      ListTile(
                        leading: const Icon(Icons.airplanemode_active),
                        title: Text('Drone ${i + 1}'),
                        subtitle: Text(drones[i].status == DroneStatus.idle
                            ? 'Status: Idle'
                            : 'Exploring (${drones[i].ticksRemaining}s left)'),
                        trailing: drones[i].status == DroneStatus.idle
                            ? ElevatedButton(
                                onPressed: () => controller.sendDroneToExplore(row, col, i),
                                child: const Text('Explore'),
                              )
                            : null,
                      ),
                    const Divider(),
                    ElevatedButton.icon(
                      onPressed: () => controller.createDrone(row, col),
                      icon: const Icon(Icons.add),
                      label: const Text('Build Drone'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Close'),
                )
              ],
            );
          },
        );
      },
    );
  }

  void _showTrainStopDialog(BuildContext context, WidgetRef ref, int row, int col) {
    final machine = ref.read(gameControllerProvider).grid[row][col];
    if (machine?.trainStopData == null) return;

    final textController = TextEditingController(text: machine!.trainStopData!.stationName);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Configure Train Stop'),
          content: TextField(
            controller: textController,
            decoration: const InputDecoration(labelText: 'Station Name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final newName = textController.text;
                if (newName.isNotEmpty) {
                  ref.read(gameControllerProvider.notifier).setTrainStopName(row, col, newName);
                }
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showStorageOutputDialog(BuildContext context, WidgetRef ref, int row, int col) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        final allResources = ResourceType.values;
        return AlertDialog(
          title: const Text('Select Output Resource'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: allResources.length + 1, // +1 for "Nothing"
              itemBuilder: (context, index) {
                if (index == allResources.length) {
                  // "Nothing" option
                  return ListTile(
                    title: const Text('Nothing'),
                    onTap: () {
                      ref.read(gameControllerProvider.notifier).setStorageOutput(row, col, null);
                      Navigator.of(dialogContext).pop();
                    },
                  );
                }
                final resource = allResources[index];
                if (resource.isFluid) {
                  // Don't show fluids in the storage selection dialog
                  // as they can't be pulled from global inventory.
                  return const SizedBox.shrink();
                }
                return ListTile(
                  leading: _buildResource(resource),
                  title: Text(resource.name),
                  onTap: () {
                    ref.read(gameControllerProvider.notifier).setStorageOutput(row, col, resource);
                    Navigator.of(dialogContext).pop();
                  },
                );
              },
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildResource(ResourceType resource) {
    // A simple colored circle to represent a resource.
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: resource.color,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _CharacterPanel extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameState = ref.watch(gameControllerProvider);
    final player = gameState.player;
    final controller = ref.read(gameControllerProvider.notifier);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Hand Crafting', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (player.craftingQueue.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Crafting: ${player.craftingQueue.first.outputs.keys.first.name}'),
                const SizedBox(height: 4),
                LinearProgressIndicator(value: player.craftingProgress / player.craftingQueue.first.productionTime),
                const SizedBox(height: 8),
              ],
            ),
          ...handCraftingRecipes.map((recipe) {
            // Only show recipe if prerequisites are met (e.g., power armor for exoskeleton)
            if (recipe.outputs.keys.first == ResourceType.exoskeletonLegs && !gameState.unlockedResearch.contains(ResearchType.powerArmor)) {
              return const SizedBox.shrink();
            }
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(recipe.outputs.keys.first.name),
                        ...recipe.inputs.entries.map((e) => Text('${e.key.name}: ${e.value}', style: Theme.of(context).textTheme.bodySmall)),
                      ],
                    ),
                    ElevatedButton(onPressed: () => controller.handCraft(recipe), child: const Text('Craft')),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 24),
          const Text('Inventory', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const Divider(),
          ListView.builder(
            itemCount: gameState.inventory.length,
            shrinkWrap: true, // Important for ListView inside SingleChildScrollView
            physics: const NeverScrollableScrollPhysics(), // Scrolling is handled by parent
            itemBuilder: (context, index) {
              final entry = gameState.inventory.entries.elementAt(index);
              // Don't show resources the player has none of.
              if (entry.value <= 0) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Text('${entry.key.name}: ${entry.value}', style: const TextStyle(fontSize: 16)),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CorePanel extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final core = ref.watch(gameControllerProvider.select((s) => s.factoryCore));

    if (core == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'Research and build the Factory Core to win the game.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (core.isComplete) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'Congratulations!\nThe Factory Core is complete!',
            style: TextStyle(fontSize: 24, color: Colors.green, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final requirements = factoryCorePhaseRequirements[core.phase];
    final progress = core.progress;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Factory Core: Phase ${core.phase + 1}', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          ...requirements.entries.map((entry) => _ProgressIndicator(resource: entry.key, have: progress[entry.key] ?? 0, needed: entry.value)),
        ],
      ),
    );
  }
}

class _BuildPanel extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameState = ref.watch(gameControllerProvider);
    final unlocked = gameState.unlockedResearch;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Buildings', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          BuildingCard(tool: Tool.coalMiner, selectedTool: gameState.selectedTool),
          BuildingCard(tool: Tool.miner, selectedTool: gameState.selectedTool),
          if (unlocked.contains(ResearchType.copperProcessing))
            BuildingCard(tool: Tool.copperMiner, selectedTool: gameState.selectedTool),
          BuildingCard(tool: Tool.smelter, selectedTool: gameState.selectedTool),
          BuildingCard(tool: Tool.assembler, selectedTool: gameState.selectedTool),
          BuildingCard(tool: Tool.storage, selectedTool: gameState.selectedTool),
          BuildingCard(tool: Tool.grinder, selectedTool: gameState.selectedTool),
          const SizedBox(height: 16),
          const Text('Logistics', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          BuildingCard(tool: Tool.conveyor, selectedTool: gameState.selectedTool),
          if (unlocked.contains(ResearchType.oilProcessing))
            BuildingCard(tool: Tool.pipe, selectedTool: gameState.selectedTool),
          if (unlocked.contains(ResearchType.logistics)) ...[
            BuildingCard(tool: Tool.splitter, selectedTool: gameState.selectedTool),
            BuildingCard(tool: Tool.merger, selectedTool: gameState.selectedTool),
          ],
          if (unlocked.contains(ResearchType.powerGeneration)) ...[
            const SizedBox(height: 16),
            const Text('Power', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            BuildingCard(tool: Tool.coalGenerator, selectedTool: gameState.selectedTool), BuildingCard(tool: Tool.powerPole, selectedTool: gameState.selectedTool),
          ],
          if (unlocked.contains(ResearchType.oilProcessing)) ...[
            const SizedBox(height: 16),
            const Text('Oil & Gas', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            BuildingCard(tool: Tool.offshorePump, selectedTool: gameState.selectedTool),
            BuildingCard(tool: Tool.oilDerrick, selectedTool: gameState.selectedTool),
            BuildingCard(tool: Tool.refinery, selectedTool: gameState.selectedTool),
            if (unlocked.contains(ResearchType.plastics))
              BuildingCard(tool: Tool.chemicalPlant, selectedTool: gameState.selectedTool),
          ],
          if (unlocked.contains(ResearchType.automatedRailways)) ...[
            const SizedBox(height: 16),
            const Text('Railways', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            BuildingCard(tool: Tool.rail, selectedTool: gameState.selectedTool),
            BuildingCard(tool: Tool.trainStop, selectedTool: gameState.selectedTool),
          ],
          if (unlocked.contains(ResearchType.military)) ...[
            const SizedBox(height: 16),
            const Text('Military', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            BuildingCard(tool: Tool.wall, selectedTool: gameState.selectedTool),
            BuildingCard(tool: Tool.gunTurret, selectedTool: gameState.selectedTool),
          ],
          if (unlocked.contains(ResearchType.tier2Machines)) ...[
            const SizedBox(height: 16),
            const Text('Tier 2 Buildings', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            BuildingCard(tool: Tool.coalMinerT2, selectedTool: gameState.selectedTool),
            BuildingCard(tool: Tool.minerT2, selectedTool: gameState.selectedTool),
            if (unlocked.contains(ResearchType.copperProcessing))
              BuildingCard(tool: Tool.copperMinerT2, selectedTool: gameState.selectedTool),
            BuildingCard(tool: Tool.smelterT2, selectedTool: gameState.selectedTool),
            BuildingCard(tool: Tool.assemblerT2, selectedTool: gameState.selectedTool),
            if (unlocked.contains(ResearchType.drones))
              BuildingCard(tool: Tool.droneStation, selectedTool: gameState.selectedTool),
          ],
          if (unlocked.contains(ResearchType.factoryCoreConstruction)) ...[
            const SizedBox(height: 16),
            const Text('End Game', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            BuildingCard(tool: Tool.factoryCore, selectedTool: gameState.selectedTool),
          ],
          const SizedBox(height: 16),
          const Text('Other', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ToolButton(tool: Tool.inspect, selectedTool: gameState.selectedTool),
              ToolButton(tool: Tool.demolish, selectedTool: gameState.selectedTool),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProgressIndicator extends StatelessWidget {
  const _ProgressIndicator({
    required this.resource,
    required this.have,
    required this.needed,
  });

  final ResourceType resource;
  final int have;
  final int needed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${resource.name}: $have / $needed'),
          const SizedBox(height: 4),
          LinearProgressIndicator(value: have / needed, minHeight: 6, color: resource.color),
        ],
      ),
    );
  }
}

class _ResearchPanel extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final researchTypes = allResearch.keys.toList();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: researchTypes.length,
      itemBuilder: (context, index) {
        return ResearchCard(type: researchTypes[index]);
      },
    );
  }
}

class ToolButton extends ConsumerWidget {
  const ToolButton({
    super.key,
    required this.tool,
    required this.selectedTool,
  });

  final Tool tool;
  final Tool selectedTool;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSelected = tool == selectedTool;
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? Theme.of(context).colorScheme.primary : null,
        foregroundColor: isSelected ? Theme.of(context).colorScheme.onPrimary : null,
      ),
      onPressed: () {
        ref.read(gameControllerProvider.notifier).selectTool(tool);
      },
      // Capitalize first letter for display
      child: Text(tool.name[0].toUpperCase() + tool.name.substring(1)),
    );
  }
}

class ResearchCard extends ConsumerWidget {
  const ResearchCard({super.key, required this.type});

  final ResearchType type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final research = allResearch[type]!;
    final gameState = ref.watch(gameControllerProvider);
    final controller = ref.read(gameControllerProvider.notifier);

    final isUnlocked = gameState.unlockedResearch.contains(type);
    final canAfford = gameState.points >= research.cost;
    final prereqsMet = gameState.unlockedResearch.containsAll(research.prerequisites);

    final canResearch = !isUnlocked && canAfford && prereqsMet;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isUnlocked ? 0 : 2,
      color: isUnlocked ? Theme.of(context).colorScheme.surfaceContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(research.name, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              research.description,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Cost: ${research.cost} Points', style: Theme.of(context).textTheme.bodyMedium),
                if (isUnlocked)
                  const Text('Researched', style: TextStyle(color: Colors.green))
                else
                  ElevatedButton(
                    onPressed: canResearch ? () => controller.unlockResearch(type) : null,
                    child: const Text('Research'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class BuildingCard extends ConsumerWidget {
  const BuildingCard({
    super.key,
    required this.tool,
    required this.selectedTool,
  });

  final Tool tool;
  final Tool selectedTool;

  String _getDisplayName(Tool tool) {
    var name = tool.name;
    if (name.isEmpty) return '';

    // Handle tier suffix
    String tierSuffix = '';
    if (name.endsWith('T2')) {
      tierSuffix = ' T2';
      name = name.substring(0, name.length - 2);
    }

    // Add space before capital letters for camelCase names
    final withSpaces = name.replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(1)}');
    return (withSpaces[0].toUpperCase() + withSpaces.substring(1)) + tierSuffix;
  }

  Map<ResourceType, int> _getCostForTool(Tool tool) {
    switch (tool) {
      case Tool.coalMiner:
        return machineCosts[MachineType.coalMiner]!;
      case Tool.miner:
        return machineCosts[MachineType.miner]!;
      case Tool.copperMiner:
        return machineCosts[MachineType.copperMiner]!;
      case Tool.coalGenerator:
        return machineCosts[MachineType.coalGenerator]!;
      case Tool.powerPole:
        return machineCosts[MachineType.powerPole]!;
      case Tool.smelter:
        return machineCosts[MachineType.smelter]!;
      case Tool.refinery:
        return machineCosts[MachineType.refinery]!;
      case Tool.chemicalPlant:
        return machineCosts[MachineType.chemicalPlant]!;
      case Tool.assembler:
        return machineCosts[MachineType.assembler]!;
      case Tool.droneStation:
        return machineCosts[MachineType.droneStation]!;
      case Tool.wall:
        return machineCosts[MachineType.wall]!;
      case Tool.gunTurret:
        return machineCosts[MachineType.gunTurret]!;
      case Tool.trainStop:
        return machineCosts[MachineType.trainStop]!;
      case Tool.offshorePump:
        return machineCosts[MachineType.offshorePump]!;
      case Tool.oilDerrick:
        return machineCosts[MachineType.oilDerrick]!;
      case Tool.storage:
        return machineCosts[MachineType.storage]!;
      case Tool.grinder:
        return machineCosts[MachineType.grinder]!;
      case Tool.coalMinerT2:
        return machineCosts[MachineType.coalMinerT2]!;
      case Tool.minerT2:
        return machineCosts[MachineType.minerT2]!;
      case Tool.copperMinerT2:
        return machineCosts[MachineType.copperMinerT2]!;
      case Tool.smelterT2:
        return machineCosts[MachineType.smelterT2]!;
      case Tool.assemblerT2:
        return machineCosts[MachineType.assemblerT2]!;
      case Tool.conveyor:
        return conveyorCost;
      case Tool.rail:
        return railCost;
      case Tool.pipe:
        return pipeCost;
      case Tool.splitter:
        return conveyorSplitterCost;
      case Tool.merger:
        return conveyorMergerCost;
      case Tool.factoryCore:
        return factoryCorePlacementCost;
      default: // For tools with no cost like inspect, demolish
        return {};
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cost = _getCostForTool(tool);
    final displayName = _getDisplayName(tool);
    final isSelected = tool == selectedTool;

    return Card(
      elevation: isSelected ? 8 : 2,
      color: isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(displayName, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...cost.entries.map((entry) => Text('${entry.key.name}: ${entry.value}', style: Theme.of(context).textTheme.bodySmall)),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: () => ref.read(gameControllerProvider.notifier).selectTool(tool), child: const Text('Select')),
          ],
        ),
      ),
    );
  }
}

class GridTileWidget extends StatelessWidget {
  const GridTileWidget({
    super.key,
    this.machine,
    this.rail,
    this.train,
    this.nest,
    this.enemiesOnTile = const [],
    this.isPlayerHere = false,
    this.pollution = 0,
    this.pipe,
    this.conveyor,
    this.isPartOfCore = false,
    this.corePartRow,
    this.corePartCol,
    this.factoryCoreState,
    this.resourceOnTile,
  });

  final Machine? machine;
  final Rail? rail;
  final Train? train;
  final EnemyNest? nest;
  final List<Enemy> enemiesOnTile;
  final bool isPlayerHere;
  final int pollution;
  final Pipe? pipe;
  final Conveyor? conveyor;
  final bool isPartOfCore;
  final int? corePartRow;
  final int? corePartCol;
  final FactoryCoreState? factoryCoreState;
  final ResourceType? resourceOnTile;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade700),
        color: Colors.grey.shade800,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Render Resource Patch
          if (resourceOnTile != null) _buildResourcePatch(resourceOnTile!),

          // Render Pollution
          if (pollution > 10) _buildPollution(pollution),

          // Render Factory Core
          if (isPartOfCore) _buildFactoryCoreTile(),

          // Render Rail
          if (rail != null) _buildRail(),

          // Render Pipe
          if (pipe != null) _buildPipe(pipe!),

          // Render Conveyor
          if (conveyor != null) _buildConveyor(conveyor!),

          // Render Machine
          if (machine != null) _buildMachine(machine!),

          // Render Enemy Nest
          if (nest != null) _buildEnemyNest(nest!),

          // Render Enemies
          ...enemiesOnTile.map((e) => _buildEnemy(e)),

          // Render Player
          if (isPlayerHere) _buildPlayer(),

          // Render Train
          if (train != null) _buildTrain(train!),

          // Render Resource on Conveyor
          if (conveyor?.resource != null) _buildResource(conveyor!.resource!),

          // Render Fluid in Pipe
          if (pipe?.fluid != null) _buildFluid(pipe!),
        ],
      ),
    );
  }

  Widget _buildFactoryCoreTile() {
    final isCenter = corePartRow == 1 && corePartCol == 1;
    return Container(
      decoration: BoxDecoration(
        color: isCenter ? Colors.purple.shade900 : Colors.purple.shade800.withAlpha(200),
        border: Border.all(
          color: Colors.purple.shade300,
          width: isCenter ? 2 : 1,
        ),
      ),
      child: isCenter
          ? Icon(Icons.hub, color: Colors.yellow.shade600, size: 32)
          : null,
    );
  }

  Widget _buildMachine(Machine machine) {
    IconData icon;
    switch (machine.type) {
      case MachineType.coalMiner:
      case MachineType.coalMinerT2:
        icon = Icons.hardware; // A pickaxe-like icon
        break;
      case MachineType.miner:
      case MachineType.minerT2:
        icon = Icons.construction;
        break;
      case MachineType.offshorePump:
        icon = Icons.water;
        break;
      case MachineType.oilDerrick:
        icon = Icons.oil_barrel;
        break;
      case MachineType.refinery:
        icon = Icons.factory;
        break;
      case MachineType.chemicalPlant:
        icon = Icons.science;
        break;
      case MachineType.wall:
        icon = Icons.crop_square;
        break;
      case MachineType.gunTurret:
        icon = Icons.camera_outdoor;
        break;
      case MachineType.coalGenerator:
        icon = Icons.bolt;
        break;
      case MachineType.powerPole:
        icon = Icons.power;
        break;
      case MachineType.copperMiner:
      case MachineType.copperMinerT2:
        icon = Icons.diamond_outlined;
        break;
      case MachineType.smelter:
      case MachineType.smelterT2:
        icon = Icons.fireplace;
        break;
      case MachineType.assembler:
      case MachineType.assemblerT2:
        icon = Icons.settings; // Using settings icon for assembler
        break;
      case MachineType.trainStop:
        icon = Icons.train;
        break;
      case MachineType.droneStation:
        icon = Icons.satellite_alt;
        break;
      case MachineType.storage:
        icon = Icons.inventory_2_outlined;
        break;
      case MachineType.grinder:
        icon = Icons.recycling;
        break;
    }
    final machineIcon = Icon(icon, color: Colors.white, size: 32);

    List<Widget> indicators = [];
    // All machines have an output.
    indicators.add(_buildOutputIndicator(machine.direction));

    // Machines that take input have an input indicator.
    final hasRecipeInput = allRecipes[machine.type]?.inputs.isNotEmpty ?? false;
    final isMultiRecipeMachine = machine.type == MachineType.assembler || machine.type == MachineType.assemblerT2 || machine.type == MachineType.smelter || machine.type == MachineType.smelterT2;

    if (hasRecipeInput || isMultiRecipeMachine || machine.type == MachineType.storage || machine.type == MachineType.grinder || machine.type == MachineType.coalGenerator) {
      if (machine.type == MachineType.smelter || machine.type == MachineType.smelterT2) {
        // Smelter: main input from back, coal from right
        indicators.add(_buildInputIndicator(machine.direction));
        indicators.add(_buildSideInputIndicator(machine.direction));
      } else {
        // Other machines: single input from back
        indicators.add(_buildInputIndicator(machine.direction));
      }
    }

    // For storage, show the configured output item on top.
    if (machine.type == MachineType.storage && machine.configuredOutput != null) {
      indicators.add(_buildResource(machine.configuredOutput!));
    }

    // Show health bar if damaged
    if (machine.health < 100) {
      indicators.add(Positioned(
        bottom: 2,
        child: SizedBox(width: 40, height: 4, child: LinearProgressIndicator(value: machine.health / 100, color: Colors.green, backgroundColor: Colors.red)),
      ));
    }

    final isTier2 = machine.type.name.endsWith('T2');

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        machineIcon,
        ...indicators,
        if (!machine.isPowered) _buildUnpoweredIndicator(),
        if (isTier2) _buildTierIndicator('T2'),
      ],
    );
  }

  Widget _buildResourcePatch(ResourceType resource) {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: resource.color.withAlpha((255 * 0.3).round()),
        border: Border.all(
          color: resource.color.withAlpha((255 * 0.6).round()),
          width: 2,
        ),
      ),
    );
  }

  Widget _buildUnpoweredIndicator() {
    return Positioned(
      bottom: 0,
      left: 0,
      child: Icon(
        Icons.power_off,
        color: Colors.red.shade400,
        size: 16,
      ),
    );
  }

  Widget _buildTierIndicator(String tier) {
    return Positioned(
      top: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha((255 * 0.7).round()),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          tier,
          style: const TextStyle(color: Colors.yellow, fontSize: 10, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildOutputIndicator(Direction direction) {
    IconData icon;
    double? top, bottom, left, right;
    switch (direction) {
      case Direction.up: icon = Icons.keyboard_arrow_up; top = -8; break;
      case Direction.down: icon = Icons.keyboard_arrow_down; bottom = -8; break;
      case Direction.left: icon = Icons.keyboard_arrow_left; left = -8; break;
      case Direction.right: icon = Icons.keyboard_arrow_right; right = -8; break;
    }
    return Positioned(top: top, bottom: bottom, left: left, right: right, child: Icon(icon, color: Colors.cyan.withAlpha(200), size: 20));
  }

  Widget _buildInputIndicator(Direction direction) {
    IconData icon;
    double? top, bottom, left, right;
    // Input is from the back of the machine
    switch (direction) {
      case Direction.up: icon = Icons.keyboard_arrow_down; bottom = -8; break; // input from bottom
      case Direction.down: icon = Icons.keyboard_arrow_up; top = -8; break; // input from top
      case Direction.left: icon = Icons.keyboard_arrow_right; right = -8; break; // input from right
      case Direction.right: icon = Icons.keyboard_arrow_left; left = -8; break; // input from left
    }
    return Positioned(top: top, bottom: bottom, left: left, right: right, child: Icon(icon, color: Colors.orange.withAlpha(200), size: 20));
  }

  Widget _buildSideInputIndicator(Direction direction) {
    IconData icon;
    double? top, bottom, left, right;
    // Input is from the LEFT side of the machine, relative to its facing direction
    switch (direction) {
      case Direction.up: icon = Icons.keyboard_arrow_right; left = -8; break; // input from left
      case Direction.down: icon = Icons.keyboard_arrow_left; right = -8; break; // input from right
      case Direction.left: icon = Icons.keyboard_arrow_up; bottom = -8; break; // input from bottom
      case Direction.right: icon = Icons.keyboard_arrow_down; top = -8; break; // input from top
    }
    return Positioned(top: top, bottom: bottom, left: left, right: right, child: Icon(icon, color: Colors.orange.withAlpha(200), size: 20));
  }

  Widget _buildPollution(int amount) {
    // Opacity scales with pollution amount, capped at 0.7
    final opacity = (amount / 500).clamp(0.0, 0.7);
    return Container(
      color: Colors.brown.withOpacity(opacity),
    );
  }

  Widget _buildEnemyNest(EnemyNest nest) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Icon(Icons.hive, color: Colors.red.shade900, size: 40),
        Positioned(
          top: 2,
          child: SizedBox(width: 40, height: 4, child: LinearProgressIndicator(value: nest.health / nestMaxHealth, color: Colors.red, backgroundColor: Colors.black45)),
        ),
      ],
    );
  }

  Widget _buildEnemy(Enemy enemy) {
    return Positioned(
      left: (enemy.position.$1 - enemy.position.$1.floor()) * 48,
      top: (enemy.position.$2 - enemy.position.$2.floor()) * 48,
      child: Stack(
        children: [
          const Icon(Icons.bug_report, color: Colors.limeAccent, size: 24),
          Positioned(
            top: 0,
            child: SizedBox(width: 24, height: 2, child: LinearProgressIndicator(value: enemy.health / enemyMaxHealth, color: Colors.red, backgroundColor: Colors.transparent)),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayer() {
    return const Icon(Icons.person, color: Colors.cyan, size: 32);
  }

  Widget _buildRail() {
    return Center(
      child: Container(
        color: Colors.brown.shade800,
        width: 48,
        height: 8,
      ),
    );
  }

  Widget _buildTrain(Train train) {
    return const Icon(Icons.train_outlined, color: Colors.yellow, size: 36);
  }

  Widget _buildPipe(Pipe pipe) {
    return Center(
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: Colors.blueGrey.shade700,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.blueGrey.shade400, width: 2),
        ),
      ),
    );
  }

  Widget _buildFluid(Pipe pipe) {
    return Center(
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: pipe.fluid!.color, shape: BoxShape.circle),
      ),
    );
  }

  Widget _buildConveyor(Conveyor conveyor) {
    if (conveyor.type == ConveyorType.splitter) {
      // --- Render Splitter ---
      final splitterIcon = Icon(Icons.call_split, color: Colors.white.withAlpha(150), size: 32);

      // A splitter has one input (back) and two outputs (front, right)
      final frontIndicator = _buildOutputIndicator(conveyor.direction);
      final inputIndicator = _buildInputIndicator(conveyor.direction);

      // Calculate right direction (clockwise)
      Direction rightDir;
      switch (conveyor.direction) {
        case Direction.up: rightDir = Direction.right; break;
        case Direction.right: rightDir = Direction.down; break;
        case Direction.down: rightDir = Direction.left; break;
        case Direction.left: rightDir = Direction.up; break;
      }
      final rightIndicator = _buildOutputIndicator(rightDir);

      return Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          splitterIcon,
          inputIndicator,
          frontIndicator,
          rightIndicator,
        ],
      );
    }

    if (conveyor.type == ConveyorType.merger) {
      // --- Render Merger ---
      final mergerIcon = Icon(Icons.merge_type, color: Colors.white.withAlpha(150), size: 32);

      // A merger has one output (front) and two inputs (back, left)
      final outputIndicator = _buildOutputIndicator(conveyor.direction);
      final inputBackIndicator = _buildInputIndicator(conveyor.direction);

      // Calculate left direction (counter-clockwise)
      Direction leftDir;
      switch (conveyor.direction) {
        case Direction.up: leftDir = Direction.left; break;
        case Direction.left: leftDir = Direction.down; break;
        case Direction.down: leftDir = Direction.right; break;
        case Direction.right: leftDir = Direction.up; break;
      }
      final inputLeftIndicator = _buildInputIndicator(leftDir);

      return Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [mergerIcon, outputIndicator, inputBackIndicator, inputLeftIndicator],
      );
    }

    IconData icon;
    switch (conveyor.direction) {
      case Direction.up:
        icon = Icons.arrow_upward;
        break;
      case Direction.down:
        icon = Icons.arrow_downward;
        break;
      case Direction.left:
        icon = Icons.arrow_back;
        break;
      case Direction.right:
        icon = Icons.arrow_forward;
        break;
    }
    // A simple icon to show the belt's direction.
    // Opacity of 0.3 is an alpha value of (255 * 0.3).round() = 77
    return Icon(icon, color: Colors.white.withAlpha(77), size: 24);
  }

  Widget _buildResource(ResourceType resource) {
    // A simple colored circle to represent a resource.
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: resource.color,
        shape: BoxShape.circle,
      ),
    );
  }
}

extension ResourceColor on ResourceType {
  Color get color {
    switch (this) {
      case ResourceType.ironOre:
        return Colors.brown;
      case ResourceType.copperOre:
        return Colors.orange;
      case ResourceType.coal:
        return Colors.black;
      case ResourceType.ironIngot:
        return Colors.blueGrey;
      case ResourceType.ironPlate:
        return Colors.grey;
      case ResourceType.copperPlate:
        return Colors.deepOrangeAccent;
      case ResourceType.copperWire:
        return Colors.orangeAccent;
      case ResourceType.circuit:
        return Colors.green;
      case ResourceType.plastic:
        return Colors.blue.shade200;
      case ResourceType.exoskeletonLegs:
        return Colors.grey.shade400;
      case ResourceType.ammunition:
        return Colors.yellow.shade800;
      case ResourceType.water:
        return Colors.blue;
      case ResourceType.crudeOil:
        return Colors.black;
      case ResourceType.petroleumGas:
        return Colors.purple.shade300;
      case ResourceType.oilSeep:
        return Colors.green.shade900;
    }
  }
}