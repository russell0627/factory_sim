import 'package:factory_sim/models/machine.dart';
import 'package:factory_sim/models/resource.dart';

/// Defines a production recipe for a machine.
class Recipe {
  const Recipe({
    this.inputs = const {},
    required this.outputs,
    required this.productionTime,
  });

  /// The resources required to start production.
  final Map<ResourceType, int> inputs;

  /// The resources produced after one cycle.
  final Map<ResourceType, int> outputs;

  /// The number of game ticks required to complete one cycle.
  final int productionTime;
}

/// A central map of all machine recipes in the game.
final Map<MachineType, Recipe> allRecipes = {
  MachineType.miner: const Recipe(
    // Miners don't have inputs, they generate resources.
    outputs: {ResourceType.ironOre: 1},
    productionTime: 5, // Takes 5 ticks to mine one ore
  ),
  // Recipes for Smelter and Assembler will be added here later.
};