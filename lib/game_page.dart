import 'package:factory_sim/ctrl/game_controller.dart';
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
                      case Tool.miner:
                        gameController.placeMachine(MachineType.miner, row, col);
                        break;
                      case Tool.conveyor:
                        // For now, conveyors are always placed facing down.
                        // A more advanced UI could allow for directional input.
                        gameController.placeConveyor(Direction.down, row, col);
                        break;
                      case Tool.demolish:
                        gameController.removeMachine(row, col);
                        gameController.removeConveyor(row, col);
                        break;
                      default:
                        // Inspect or other tools do nothing on tap for now.
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
              color: Theme.of(context).colorScheme.surfaceVariant,
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Tools', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ToolButton(tool: Tool.miner, selectedTool: gameState.selectedTool),
                      ToolButton(tool: Tool.conveyor, selectedTool: gameState.selectedTool),
                      ToolButton(tool: Tool.demolish, selectedTool: gameState.selectedTool),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text('Inventory', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const Divider(),
                  Expanded(
                    child: ListView(
                      children: gameState.inventory.entries.map((entry) {
                        // Don't show resources the player has none of.
                        if (entry.value <= 0) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Text('${entry.key.name}: ${entry.value}', style: const TextStyle(fontSize: 16)),
                        );
                      }).toList(),
                    ),
                  ),
                ],
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
      case MachineType.miner:
        icon = Icons.construction;
        break;
      case MachineType.smelter:
        icon = Icons.fireplace;
        break;
      case MachineType.assembler:
        icon = Icons.handyman;
        break;
    }
    return Icon(icon, color: Colors.white, size: 32);
  }

  Widget _buildConveyor(Conveyor conveyor) {
    IconData icon;
    switch (conveyor.direction) {
      case Direction.up:
        icon = Icons.arrow_upward;
      case Direction.down:
        icon = Icons.arrow_downward;
      case Direction.left:
        icon = Icons.arrow_back;
      case Direction.right:
        icon = Icons.arrow_forward;
    }
    // A simple icon to show the belt's direction.
    return Icon(icon, color: Colors.white.withOpacity(0.3), size: 24);
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
      case ResourceType.ironPlate:
        return Colors.grey;
      case ResourceType.copperPlate:
        return Colors.deepOrangeAccent;
    }
  }
}