import 'package:factory_sim/ctrl/game_controller.dart';
import 'package:factory_sim/models/recipe.dart';
import 'package:factory_sim/models/building_data.dart';
import 'package:factory_sim/models/conveyor.dart';
import 'package:factory_sim/models/tool.dart';
import 'package:factory_sim/models/machine.dart';
import 'package:factory_sim/models/resource.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
        ],
      ),
      body: Row(
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

                final machine = gameState.grid[row][col];
                final conveyor = gameState.conveyorGrid[row][col];

                return GestureDetector(
                  onTap: () {
                    switch (gameState.selectedTool) {
                      case Tool.coalMiner:
                      case Tool.miner:
                      case Tool.smelter:
                      case Tool.assembler:
                      case Tool.storage:
                      case Tool.grinder:
                        if (machine != null) {
                          gameController.rotateMachine(row, col);
                        } else {
                          const toolToMachine = {
                            Tool.coalMiner: MachineType.coalMiner,
                            Tool.miner: MachineType.miner,
                            Tool.smelter: MachineType.smelter,
                            Tool.assembler: MachineType.assembler,
                            Tool.storage: MachineType.storage,
                            Tool.grinder: MachineType.grinder,
                          };
                          final typeToPlace = toolToMachine[gameState.selectedTool];
                          if (typeToPlace != null) {
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
                      case Tool.demolish:
                        gameController.removeMachine(row, col);
                        gameController.removeConveyor(row, col);
                        break;
                      case Tool.inspect:
                        if (machine?.type == MachineType.storage) {
                          gameController.cycleStorageOutput(row, col);
                        }
                        break;
                    }
                  },
                  child: GridTileWidget(
                    machine: machine,
                    conveyor: conveyor,
                  ),
                );
              },
            ),
          ),
          // Control Panel
          Expanded(
            flex: 1,
            child: Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Buildings', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    BuildingCard(tool: Tool.coalMiner, selectedTool: gameState.selectedTool),
                    BuildingCard(tool: Tool.miner, selectedTool: gameState.selectedTool),
                    BuildingCard(tool: Tool.smelter, selectedTool: gameState.selectedTool),
                    BuildingCard(tool: Tool.assembler, selectedTool: gameState.selectedTool),
                    BuildingCard(tool: Tool.storage, selectedTool: gameState.selectedTool),
                    BuildingCard(tool: Tool.grinder, selectedTool: gameState.selectedTool),
                    const SizedBox(height: 16),
                    const Text('Logistics', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    BuildingCard(tool: Tool.conveyor, selectedTool: gameState.selectedTool),
                    BuildingCard(tool: Tool.splitter, selectedTool: gameState.selectedTool),
                    BuildingCard(tool: Tool.merger, selectedTool: gameState.selectedTool),
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
              ),
            ),
          ),
        ],
      ),
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

class BuildingCard extends ConsumerWidget {
  const BuildingCard({
    super.key,
    required this.tool,
    required this.selectedTool,
  });

  final Tool tool;
  final Tool selectedTool;

  String _getDisplayName(Tool tool) {
    final name = tool.name;
    if (name.isEmpty) return '';
    // Add space before capital letters for camelCase names
    final withSpaces = name.replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(1)}');
    return withSpaces[0].toUpperCase() + withSpaces.substring(1);
  }

  Map<ResourceType, int> _getCostForTool(Tool tool) {
    switch (tool) {
      case Tool.coalMiner:
        return machineCosts[MachineType.coalMiner]!;
      case Tool.miner:
        return machineCosts[MachineType.miner]!;
      case Tool.smelter:
        return machineCosts[MachineType.smelter]!;
      case Tool.assembler:
        return machineCosts[MachineType.assembler]!;
      case Tool.storage:
        return machineCosts[MachineType.storage]!;
      case Tool.grinder:
        return machineCosts[MachineType.grinder]!;
      case Tool.conveyor:
        return conveyorCost;
      case Tool.splitter:
        return conveyorSplitterCost;
      case Tool.merger:
        return conveyorMergerCost;
      default:
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
    this.conveyor,
  });

  final Machine? machine;
  final Conveyor? conveyor;

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
          // Render Conveyor
          if (conveyor != null) _buildConveyor(conveyor!),

          // Render Machine
          if (machine != null) _buildMachine(machine!),

          // Render Resource on Conveyor
          if (conveyor?.resource != null) _buildResource(conveyor!.resource!),
        ],
      ),
    );
  }

  Widget _buildMachine(Machine machine) {
    IconData icon;
    switch (machine.type) {
      case MachineType.coalMiner:
        icon = Icons.hardware; // A pickaxe-like icon
        break;
      case MachineType.miner:
        icon = Icons.construction;
        break;
      case MachineType.smelter:
        icon = Icons.fireplace;
        break;
      case MachineType.assembler:
        icon = Icons.settings; // Using settings icon for assembler
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
    if (hasRecipeInput || machine.type == MachineType.storage || machine.type == MachineType.grinder) {
      if (machine.type == MachineType.smelter) {
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

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        machineIcon,
        ...indicators,
      ],
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

  Widget _buildConveyor(Conveyor conveyor) {
    if (conveyor.type == ConveyorType.splitter) {
      // --- Render Splitter ---
      final splitterIcon = Icon(Icons.call_split, color: Colors.white.withAlpha(150), size: 32);

      // A splitter has two outputs, front and right
      final frontIndicator = _buildOutputIndicator(conveyor.direction);

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
    }
  }
}