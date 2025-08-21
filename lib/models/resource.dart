/// Enum for all types of resources in the game.
enum ResourceType {
  // Solids
  ironOre,
  copperOre,
  coal,
  ironIngot,
  ironPlate,
  copperPlate,
  copperWire,
  circuit,
  plastic,

  // Fluids
  water,
  crudeOil,
  petroleumGas,

  // Patches (not inventory items)
  oilSeep,
}

extension ResourceProperties on ResourceType {
  bool get isFluid {
    return {ResourceType.water, ResourceType.crudeOil, ResourceType.petroleumGas}.contains(this);
  }
}