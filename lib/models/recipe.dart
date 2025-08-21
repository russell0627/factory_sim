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
  MachineType.coalMiner: const Recipe(
    // Miners don't have inputs, they generate resources.
    outputs: {ResourceType.coal: 1},
    productionTime: 4, // Takes 4 ticks to mine one coal
  ),
  MachineType.miner: const Recipe(
    // Miners don't have inputs, they generate resources.
    outputs: {ResourceType.ironOre: 1},
    productionTime: 4, // Takes 4 ticks to mine one ore
  ),
  MachineType.copperMiner: const Recipe(
    outputs: {ResourceType.copperOre: 1},
    productionTime: 4,
  ),
  MachineType.offshorePump: const Recipe(
    outputs: {ResourceType.water: 25}, // Produces 25 units of water per cycle
    productionTime: 1, // Very fast
  ),
  MachineType.oilDerrick: const Recipe(
    outputs: {ResourceType.crudeOil: 20},
    productionTime: 2,
  ),

  // Tier 2 Recipes
  MachineType.coalMinerT2: const Recipe(
    outputs: {ResourceType.coal: 1},
    productionTime: 2,
  ),
  MachineType.minerT2: const Recipe(
    outputs: {ResourceType.ironOre: 1},
    productionTime: 2,
  ),
  MachineType.copperMinerT2: const Recipe(
    outputs: {ResourceType.copperOre: 1},
    productionTime: 2,
  ),
};

/// A list of all recipes a Smelter can use.
final List<Recipe> smelterRecipes = [
  // Tier 1
  const Recipe(
    inputs: {ResourceType.ironOre: 1, ResourceType.coal: 1},
    outputs: {ResourceType.ironIngot: 1},
    productionTime: 4,
  ),
  const Recipe(
    inputs: {ResourceType.copperOre: 1, ResourceType.coal: 1},
    outputs: {ResourceType.copperPlate: 1},
    productionTime: 4,
  ),
];

/// A list of all recipes an Assembler can use.
final List<Recipe> assemblerRecipes = [
  // Tier 1
  const Recipe(
    inputs: {ResourceType.ironIngot: 2}, // Takes 2 ingots to make a plate
    outputs: {ResourceType.ironPlate: 1},
    productionTime: 4,
  ),
  const Recipe(
    inputs: {ResourceType.copperPlate: 1},
    outputs: {ResourceType.copperWire: 2},
    productionTime: 2, // Wires are fast
  ),
  const Recipe(
    inputs: {ResourceType.ironPlate: 1, ResourceType.copperWire: 3},
    outputs: {ResourceType.circuit: 1},
    productionTime: 6, // Circuits are complex
  ),
];

/// A list of all recipes a Refinery can use.
final List<Recipe> refineryRecipes = [
  const Recipe(
    inputs: {ResourceType.crudeOil: 100},
    outputs: {ResourceType.petroleumGas: 50},
    productionTime: 5,
  ),
];

/// A list of all recipes a Chemical Plant can use.
final List<Recipe> chemicalPlantRecipes = [
  const Recipe(
    inputs: {ResourceType.petroleumGas: 20, ResourceType.coal: 10},
    outputs: {ResourceType.plastic: 2},
    productionTime: 6,
  ),
];

// Tier 2 recipes are just faster versions. We can generate them.
final List<Recipe> smelterRecipesT2 = smelterRecipes.map((r) => Recipe(inputs: r.inputs, outputs: r.outputs, productionTime: (r.productionTime / 2).ceil())).toList();
final List<Recipe> assemblerRecipesT2 = assemblerRecipes.map((r) => Recipe(inputs: r.inputs, outputs: r.outputs, productionTime: (r.productionTime / 2).ceil())).toList();