# Wolf Down lightweight effects

`particle_fx.gd` provides shared GPU particle bursts for muzzle flashes, hits, enemy deaths, player damage, score rewards, objective completion, and pickups.

The effect system is intentionally lightweight:
- very small 16x16 particle texture
- short lifetimes
- low particle counts
- one-shot GPU particles
- global cap of 60 simultaneous effects
- no collision-based particles
- automatic cleanup after each burst

The score reward is configured in `autoload/game_manager.gd`: every 5,000 score grants +1 maximum HP and +1 current HP, up to 10 maximum HP.
