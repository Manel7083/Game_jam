# Level 1 - tilemap novo (referência visual: Level 3)

Arquivos (extraia por cima da pasta do projeto, onde fica o project.godot):
- `leveis/level_1.tscn`  substitui o atual. Só o TileMap e a câmera do lobo mudaram; level_1.gd não foi tocado
  (o level_2 usa o mesmo script e não é afetado).
- `terreno/level1_tiles.png`  atlas novo (16x16). O Godot importa sozinho ao abrir o projeto.

O que mudou
- Moldura de paredes de tijolo (6 tiles em volta) com contorno escuro, realce e musgo/rachaduras, como no level 3.
  A área jogável e as colisões internas são idênticas às de antes (o chão vai de x -30..41, y -35..7).
- Sombra projetada pelas paredes no chão (gradiente de ~10px, igual ao level 3) e escurecimento das fileiras de fora.
- Caminho em pedras vermelhas com borda chanfrada e irregular (antes era um quadrado liso).
- Grama com tom alternado sutil (xadrez do chão do level 3), tufos, folhas secas, pedrinhas e rachaduras.
- Decalques: manchas de sangue, ossos, cogumelos roxos (mesma cor das chamas do level 3).
- Camadas: chao (grama), caminho, parede (colisão), detalhes (antiga "tijolo", z_index 1, fica abaixo do lobo).
- A câmera do lobo agora tem limites na borda externa das paredes (não aparece mais o fundo roxo vazio).

Editar no editor do Godot
- A fonte nova é a `7` do TileSet. O caminho usa o terreno "caminho 2" com o conjunto completo de 47 máscaras:
  pinte na camada `caminho` com o terreno e as bordas se ajustam. A grama usa o terreno "chao".
- Paredes e decalques são colocados manualmente (paleta da fonte 7).

Regerar / mudar cores
`python3 build_level1.py <level_1.tscn original> <pasta de saída>` (requer Pillow). Paleta e formas em `gen_tiles.py`.
