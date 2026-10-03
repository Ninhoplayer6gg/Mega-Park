# Como adicionar conteúdo ao Mega Park

## Padrão visual (obrigatório): sem placeholders

Nada entra no jogo como quadrado colorido, círculo, caixa cinza, texto no lugar de arte, textura
checkerboard ou asset padrão da engine. Se a arte definitiva não existe ainda, crie uma **primeira versão
real em pixel art** (os geradores em `tools/art/` são o ponto de partida) seguindo:

- pixel art 2D, *nearest-neighbor*, sem blur; tiles de 32x32; criaturas entre 64 e 136 px;
- contorno colorido escuro (*sel-out*), sombreamento em 3–4 tons com variação de matiz
  (luz quente, sombra fria), silhueta legível;
- criaturas sempre mais contrastadas que o chão onde vivem;
- elementos de UI (barras, selos, molduras, botões) sempre com moldura 9-slice em pixel art
  (`assets/ui/frames/`) e ícone próprio (`assets/ui/icons/`).

Antes de considerar uma tela pronta, confira: (1) há algum retângulo/forma genérica representando um
objeto? (2) texto substituindo arte? (3) asset padrão da engine? (4) botão importante sem ícone?
(5) criatura sem sprite reconhecível? (6) cenário com cara de debug? O tour automático
(`godot -- --tour --shots=<pasta>`) captura todas as telas para essa revisão.

Todo o conteúdo é **data-driven**: cada criatura, habilidade, prédio, habitat, missão, expedição e
adversário da Arena é um arquivo `.tres` em `data/`. O `DataRegistry` carrega automaticamente tudo o que
estiver nessas pastas na inicialização. Na maioria dos casos **nenhum código precisa ser alterado**.

A forma mais fácil de criar um `.tres` é no editor do Godot: clique com o botão direito na pasta →
*Novo Recurso…* → escolha a classe (ex.: `CreatureData`) → preencha no Inspetor. Outra opção é duplicar
um arquivo existente e editar. **O `id` precisa ser único.**

---

## Nova criatura

1. **Sprite:** crie uma folha PNG em `assets/creatures/` com quadros do mesmo tamanho, criatura
   **olhando para a direita**, nesta ordem de linhas (o padrão de `anim_layout`):

   | linha | animação | quadros |
   |---|---|---|
   | 0 | idle | 4 |
   | 1 | walk | 6 |
   | 2 | attack | 4 |
   | 3 | hurt | 2 |
   | 4 | defeat | 4 |

   Layouts diferentes funcionam: ajuste `anim_layout` (`nome: [linha, quadros, fps, loop]`).
2. **Ovo** (opcional): PNG ~16x20 em `assets/creatures/egg_<id>.png`.
3. **Dados:** `data/creatures/<id>.tres` (classe `CreatureData`). Campos principais:
   - `id`, `display_name`, `species`, `category` (`prehistoric`, `alien`, `mythic`, `aquatic`,
     `mechanical`, `anomalous`), `rarity`, `role`, `origin`, `description`
   - atributos base (`base_health`, `base_attack`, `base_defense`, `base_speed`) e crescimento por nível
   - `abilities` (2 `AbilityData`)
   - parque: `habitat_type`, `income_amount`, `income_interval`, `income_cap`, `walk_speed`,
     `feed_cost`, `feed_xp`
   - incubação: `dna_cost`, `incubation_time`, `start_discovered`, `required_building`
   - visual: `sprite_sheet`, `frame_size`, `foot_y` (linha dos pés dentro do quadro), `battle_scale`,
     `egg_texture`, `accent_color`, `cry_sfx`
4. Pronto: ela aparece na Incubadora, no Bestiário e pode ser usada na Arena/expedições.
5. Rode `godot --headless res://tests/test_runner.tscn` para validar (os testes conferem sprite,
   animações e habilidades de todas as criaturas).

Dica: para balancear, adicione o confronto em `test_battle_balance` (simula 200 batalhas IA × IA).

## Nova habilidade

`data/abilities/<id>.tres` (classe `AbilityData`):

- `kind`: `ABILITY` para especiais (`ATTACK`, `GUARD`, `RESERVE` são as ações básicas)
- `energy_cost`, `cooldown` (rodadas), `power` (multiplicador de dano; 0 = sem dano),
  `damage_type` (`physical`, `electric` ignora 30% da defesa, `cosmic`), `priority`
- `effects`: lista de `StatusEffectData` (`target` self/enemy, `stat` attack/defense/speed/next_attack,
  `multiplier`, `duration`, `label`)
- apresentação: `vfx` (`hit`, `zap`, `sparkle`, `dust`), `sfx` (nome de arquivo em `assets/audio/sfx`),
  `icon_name` (arquivo em `assets/ui/icons`)
- `ai_weight` ajusta o quanto a IA gosta da habilidade

Depois, adicione-a ao array `abilities` de uma criatura. A IA já sabe avaliar qualquer combinação de dano
e efeitos.

## Novo prédio

`data/buildings/<id>.tres` (classe `BuildingData`):

- `sprite` (base do sprite alinhada à base do footprint), `hframes`/`anim_fps` para animação,
  `overlay_texture` (camada por cima, como o vidro da incubadora)
- `size` (casas do grid), `placement_rule` (`land`, `adjacent_fence`, `adjacent_path`),
  `max_count`, `unlock_player_level`, `required_building`
- `cost_credits`, `energy_use`, `energy_output`, `refund_ratio`
- `connects = true` para peças que se ligam aos vizinhos (folha de 16 quadros por máscara
  N=1, L=2, S=4, O=8 — veja `assets/buildings/fence_wood.png`)
- `ground_layer = true` para peças planas (caminhos)
- `node_type`: `generic`, `habitat` ou `incubator` — novos comportamentos são registrados em
  `scripts/building/building_factory.gd`
- `panel_type`: `generic`, `habitat`, `incubator` ou `research` — novos painéis em
  `scripts/ui/panels/` e registrados em `Hud.PANELS`
- `params`: dicionário livre para painéis especializados

Ele aparece sozinho no menu **Construir** (ordenado por `sort_order`).

## Novo habitat

1. Crie a arte: chão (32x32, N variações lado a lado), cerca (16 quadros 32x48), portão (~64x64),
   comedouro (32x32) e decorações.
2. `data/habitats/<tipo>.tres` (classe `HabitatTypeData`) com `id` = o tipo (ex.: `aquatic`).
3. Um prédio em `data/buildings/` com `node_type = habitat`, `panel_type = habitat`,
   `habitat_type = <tipo>` e `habitat_capacity`.
4. Criaturas com `habitat_type = <tipo>` passam a poder viver nele.

## Nova missão

`data/missions/<id>.tres` (classe `MissionData`):

- `order` (posição na sequência), `title`, `description`, `icon_name`
- `objective`: `building_placed`, `creature_hatched`, `creature_assigned`, `credits_collected`,
  `creature_level` (usa o maior nível), `creature_fed`, `battle_won`, `expedition_completed`,
  `incubation_started`
- `objective_param`: filtro opcional (categoria ou id do prédio, id da espécie/adversário/expedição)
- `target`, `reward_credits`, `reward_dna`, `reward_player_xp`

Novos tipos de objetivo: emita um sinal no `EventBus` e conecte-o em `MissionManager._ready()`.

## Nova expedição / adversário da Arena

- `data/expeditions/<id>.tres` (`ExpeditionData`): duração, custo, faixas de recompensa,
  `species_pool` e `species_sample_chance`, `region_type` (para futuros planetas/dimensões/oceanos/ruínas).
- `data/arena/<id>.tres` (`ArenaOpponentData`): `order`, `title`, `creature`, `level`, recompensas.

## Sons

Coloque `.wav`/`.ogg` em `assets/audio/sfx/` (ou `music/`). O nome do arquivo vira o id:
`AudioManager.play_sfx(&"meu_som")`. Sons ausentes são ignorados silenciosamente.

## Mudanças no formato do save

1. Aumente `SaveManager.SAVE_VERSION`.
2. Adicione `_v<N>_to_v<N+1>(data)` em `scripts/save/save_migrations.gd` e registre em `STEPS`.
3. Nunca descarte dados que a migração não conhece. Saves de versões futuras ou impossíveis de migrar
   são preservados em `user://` em vez de serem sobrescritos.
