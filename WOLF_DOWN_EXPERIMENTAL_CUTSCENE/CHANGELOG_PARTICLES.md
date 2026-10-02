# Particle tuning

Adjusted the existing lightweight particle system:

- Muzzle flash: 8 -> 4 particles, shorter lifetime, smaller scale.
- Enemy hit spark: 6 -> 3 particles, shorter lifetime, smaller scale.
- Player damage: 10 -> 5 particles, longer/softer motion, larger low-alpha particles, purple tint to read as a mist.

The shared GPU burst cap remains at 60 active effects.
