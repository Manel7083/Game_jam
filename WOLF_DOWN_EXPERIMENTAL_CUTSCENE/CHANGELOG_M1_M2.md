# Wolf Down - Milestones 1-2 (stabilize + game flow)

Existing folders kept (leveis/, terreno/, enemies_sprites/ ...). New folders: autoload/, ui/, enemies/.
NOT play-tested (no Godot available when this was written): open in Godot 4.7, let it reimport, run, report errors.

## New
- autoload/game_manager.gd  - progression, score/stats, game over, level complete, pause, retry, menu. Autoload "GameManager".
- autoload/objective_manager.gd - objective + checklist, signals. Autoload "ObjectiveManager".
- enemies/enemy_base.gd - shared enemy API (take_damage, die, attack, detect_player, move_toward_player, apply_knockback).
- leveis/level_base.gd - shared level logic (register with GameManager, objectives, capped spawning).
- ui/: pause_menu, game_over, level_complete (.tscn + .gd), controls_panel.gd, ui_kit.gd.
- leveis/menu.gd - START / CONTROL / QUIT now work. project.godot: main scene = menu, new "pause" input (Esc / Start).

## Changed (what and why)
- wolf.gd: HP persists across levels via GameManager; 0.6s invulnerability + flash; death no longer queue_free()s the
  player (it triggers Game Over); heal(); ammo made float (was int -> 2.5 truncated to 2 and regen was lossy);
  group-call HUD updates replaced by signals; shots counted for accuracy; added missing
  _on_pistol_animation_animation_finished handler; clears Global.Player on exit.
- enemie.gd: now extends EnemyBase. Fixes: enemies could never damage the player (no attack area existed) - now contact
  damage with cooldown; knockback no longer moves twice per frame; death sound plays (was cut by queue_free); one damage path.
- bullet.gd: reports hits for accuracy.
- level_1.gd: now extends level_base.gd (shared by level_1 and level_2). Spawns capped at 12 alive enemies.
- inteface.gd (HUD): signal-driven; HP shown as n/max; added score + objective checklist + "OBJECTIVE COMPLETE" banner.
  Fixed "hp" + int string bug.
- temporizador.gd: expiry now completes the objective/level through GameManager (no hard scene switch). Removed
  reference to a node that did not exist.
- transition_screen.gd: change_scene(), works while paused, ignores overlapping transitions.
- tutorial.gd: registers with GameManager; NEXT goes through it.
- singleton.gd: reduced to the player reference.

## Known / next
- Level 2 is still a copy of level 1 (survive 2:00). Completing it returns to the menu until levels 3-5/boss/victory exist.
- Ammo is still the original energy bar; real weapons/magazines/reload are Milestone 4.
- Only one enemy sprite exists (run.png); bats/vampire/cultist/demon/Dracula art must be created or supplied.
- Objective checklist uses [x]/[ ] (the font has no checkbox glyphs). No sound for objective complete yet (no asset).
