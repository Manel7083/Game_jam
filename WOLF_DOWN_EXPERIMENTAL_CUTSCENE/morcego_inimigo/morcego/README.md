# MORCEGO — pacote do inimigo

Inimigo voador em pixel art, preparado para o projeto **wolf_down** (Godot 4). O pacote foi separado para você copiar manualmente sem alterar o restante do projeto.

## Conteúdo
- `morcego.tscn` — cena pronta.
- `morcego.gd` — movimento, perseguição, ataque de contato, dano, knockback e morte.
- `morcego_idle.png` — 4 frames.
- `morcego_walk.png` — 6 frames.
- `morcego_attack.png` — 6 frames.
- `morcego_hurt.png` — 4 frames.
- `morcego_death.png` — 6 frames.
- `preview.png` — prévia das animações.

## Instalação
Copie a pasta `morcego` para a raiz do projeto, ficando assim:

`res://morcego/morcego.tscn`

Depois, no nível onde deseja usar o novo inimigo, troque a `PackedScene` de spawn para `res://morcego/morcego.tscn`.

## Animações
- `idle`: parado/voando no lugar, loop.
- `run`: perseguição, loop.
- `attack`: investida curta + dano de contato.
- `hurt`: reação ao receber dano.
- `death`: animação de morte.

## Integração
A cena entra no grupo `enemies` e expõe `take_damage()` e `update_health()`, mantendo a API usada pelo tiro e pelo ataque melee do projeto atual. Ela também usa `Global.Player` para localizar o jogador e `GameManager.register_kill()` para registrar a pontuação.

Valores padrão: **2 HP**, **72 velocidade**, **1 dano**, **150 pontos**. Eles podem ser alterados no Inspector.
