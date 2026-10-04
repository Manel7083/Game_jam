# Boss Final - Drácula (Wolf Down)

Pasta pronta para copiar para `res://boss_dracula/` no projeto Godot 4.x.

## Instalação
1. Copie a pasta `boss_dracula` inteira para a raiz do projeto (`res://boss_dracula/`).
2. Na fase final, instancie `scenes/dracula_boss.tscn` (ou use `scripts/boss_arena_example.gd` como base).
3. Opcional: instancie `scenes/boss_health_bar.tscn` e chame `bind_boss(boss)`.
4. Ajuste `arena_rect` do boss para os limites da sala (coordenadas globais).

## Integração com o seu jogo (3 pontos)
- **Jogador**: precisa estar no grupo `"player"` e ter `take_damage(n)` (também tenta `damage`, `hit`, `hurt`). Se o seu usa outro nome, edite `BossUtils.damage_player()` em `scripts/boss_utils.gd`.
- **Balas do jogador**: devem chamar `take_damage(n)` (ou `damage`/`hit`) no corpo ou na Area2D atingida. O boss tem um CharacterBody2D e uma Hurtbox Area2D (layer 1) que repassa o dano.
- **Camadas de colisão**: o boss usa layer/mask padrão (1). Se o seu jogador/paredes usam outras layers, ajuste em `dracula_boss.tscn`. Projéteis do boss somem ao bater em `StaticBody2D`/`TileMapLayer`.

## Comportamento
- **Intro**: aparece em névoa, ruge e fica invulnerável por ~3s.
- **Fase 1 (100-66%)**: persegue e orbita o jogador; ataques: leque de orbes, teleporte, poças de sangue.
- **Fase 2 (66-33%)**: mais rápido; adiciona invocação de morcegos e investida em forma de morcego; leque + anel de orbes.
- **Fase 3 (33-0%)**: enfurecido; espiral de orbes, investidas mais longas, mais poças.
- Transição entre fases: ruge, solta um anel de orbes e invoca morcegos.
- **Morte**: se desintegra, remove lacaios e emite o sinal `defeated`.

Sinais: `health_changed(current, maximum)`, `phase_changed(phase)`, `defeated`.

## Ajustes rápidos (Inspector)
`max_health`, `move_speed`, `contact_damage`, `sprite_scale`, `arena_rect`, e as cenas de projétil/poça/lacaio.
Tempos e quantidades de cada ataque ficam em `scripts/dracula_boss.gd` (seção ATAQUES).

## Sprites
Pixel art 32x32 por frame (fitas horizontais, filtro nearest). Para regenerar/alterar cores: `python3 tools/generate_sprites.py` (requer Pillow).
Se o sprite ficar pequeno/grande demais comparado ao Wolf, mude `sprite_scale`.
