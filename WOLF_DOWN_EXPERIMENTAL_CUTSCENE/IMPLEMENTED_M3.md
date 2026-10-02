# Wolf Down - M3 polish added

Implemented on top of the provided M1-M2 fixed project.

## Score -> HP reward
- Every 5,000 score grants +1 maximum HP.
- The player also recovers +1 current HP when the reward is earned.
- Maximum HP is capped at 10.
- Reward state is stored in GameManager snapshots so restarting a level does not duplicate rewards.
- HUD shows progress toward the next HP reward.
- HUD announces the reward and triggers a GPU particle burst.

## Lightweight GPU particles
Added `effects/particle_fx.gd` with a shared 16x16 particle texture and a cap of 60 simultaneous effects.

Effects included:
- weapon muzzle flash
- bullet hit spark
- enemy death burst
- player damage burst
- score/HP reward burst
- objective completion burst
- pickup burst helper for future pickups
- subtle ambient dust around the player

Performance choices:
- GPUParticles2D
- one-shot short lifetimes for combat bursts
- small particle counts
- no particle collision simulation
- shared texture loaded once
- automatic cleanup
- global active-effect cap

## Files changed
- `autoload/game_manager.gd`
- `wolf.gd`
- `bullet/bullet.gd`
- `enemies/enemy_base.gd`
- `leveis/inteface.gd`
- new: `effects/particle_fx.gd`
- new: `effects/particle_dot.png`
