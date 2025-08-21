import 'package:flutter/foundation.dart';

/// Enum for all types of research in the game.
enum ResearchType {
  logistics,
  copperProcessing,
  powerGeneration,
  tier2Machines,
  landExpansion,
  oilProcessing,
  plastics,
  factoryCoreConstruction,
  drones,
  automatedRailways,
  military,
  powerArmor,
}

/// Represents a single research item in the technology tree.
@immutable
class Research {
  const Research({
    required this.name,
    required this.description,
    required this.cost,
    this.prerequisites = const {},
  });

  final String name;
  final String description;
  final int cost; // in research points
  final Set<ResearchType> prerequisites;
}

/// A central map of all available research in the game.
final Map<ResearchType, Research> allResearch = {
  ResearchType.logistics: const Research(
    name: 'Logistics',
    description: 'Unlocks Splitters and Mergers for more complex conveyor belt systems.',
    cost: 100,
  ),
  ResearchType.copperProcessing: const Research(
    name: 'Copper Processing',
    description: 'Unlocks the Copper Miner to extract copper ore, and enables smelting and assembly of copper products.',
    cost: 150,
    prerequisites: {ResearchType.logistics},
  ),
  ResearchType.powerGeneration: const Research(
    name: 'Power Generation',
    description: 'Unlocks the Coal Generator and Power Poles to generate and distribute power.',
    cost: 200,
    prerequisites: {ResearchType.copperProcessing},
  ),
  ResearchType.oilProcessing: const Research(
    name: 'Oil Processing',
    description: 'Unlocks the Oil Derrick, Refinery, Pipes, and the ability to process crude oil.',
    cost: 400,
    prerequisites: {ResearchType.powerGeneration},
  ),
  ResearchType.plastics: const Research(
    name: 'Plastics',
    description: 'Unlocks the Chemical Plant to produce plastic from petroleum gas and coal.',
    cost: 500,
    prerequisites: {ResearchType.oilProcessing},
  ),
  ResearchType.tier2Machines: const Research(
    name: 'Advanced Machinery',
    description: 'Unlocks Tier 2 versions of production buildings that work twice as fast.',
    cost: 500,
    prerequisites: {ResearchType.plastics},
  ),
  ResearchType.landExpansion: const Research(
    name: 'Land Expansion',
    description: 'Increases the size of the buildable area by 5 in each direction.',
    cost: 400,
    prerequisites: {ResearchType.tier2Machines},
  ),
  ResearchType.factoryCoreConstruction: const Research(
    name: 'Factory Core Construction',
    description: 'Unlocks the ability to build the Factory Core, the ultimate expression of automation.',
    cost: 1000,
    prerequisites: {ResearchType.tier2Machines, ResearchType.landExpansion},
  ),
  ResearchType.drones: const Research(
    name: 'Drones',
    description: 'Unlocks the Drone Station, allowing you to build and dispatch drones for exploration and resource gathering.',
    cost: 750,
    prerequisites: {ResearchType.tier2Machines},
  ),
  ResearchType.automatedRailways: const Research(
    name: 'Automated Railways',
    description: 'Unlocks Rails, Train Stops, and Locomotives for high-throughput, long-distance transport.',
    cost: 800,
    prerequisites: {ResearchType.drones},
  ),
  ResearchType.military: const Research(
    name: 'Military',
    description: 'Unlocks Walls, Gun Turrets, and Ammunition production to defend your factory.',
    cost: 300,
    prerequisites: {ResearchType.powerGeneration},
  ),
  ResearchType.powerArmor: const Research(
    name: 'Power Armor',
    description: 'Unlocks the ability to craft and equip personal equipment, like the Exoskeleton.',
    cost: 600,
    prerequisites: {ResearchType.plastics},
  ),
};