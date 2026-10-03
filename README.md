# Mega Park

Jogo 2D em pixel art de **gerenciamento, coleção e batalha de criaturas**. Você administra um parque
interdimensional com dinossauros, criaturas alienígenas e outras espécies: constrói habitats, incuba
criaturas a partir de DNA, coleta a renda que elas geram, evolui seus níveis, batalha na Arena e
envia expedições.

- **Engine:** Godot **4.3** (renderer *GL Compatibility*, ideal para Android)
- **Plataforma principal:** Android (paisagem, touch). Também roda no PC (mouse/teclado) para testes.
- **Estado:** primeira versão jogável (v0.1.0). Veja o [CHANGELOG](CHANGELOG.md).

Toda a arte (criaturas, tiles, prédios, ícones, efeitos, arena) e todos os sons são **originais**,
gerados pelos scripts em `tools/`. A fonte é a Pixelify Sans (SIL Open Font License, `assets/fonts/OFL.txt`).

---

## Como executar

1. Instale o [Godot 4.3](https://godotengine.org/download) (versão padrão, não precisa de .NET).
2. Abra o Godot → **Importar** → selecione `project.godot` desta pasta.
3. Pressione **F5** (cena principal: `scenes/main/boot.tscn`).

Linha de comando:

```bash
godot --path .                      # joga
godot --path . -- --scene=park      # pula a tela de título
```

### Exportar para Android

1. No Godot: *Editor → Gerenciar modelos de exportação* → baixe os templates 4.3.
2. *Editor → Configurações do editor → Exportar → Android*: configure o Android SDK e o keystore de debug.
3. *Projeto → Exportar…* → preset **Android** (já configurado: arm64-v8a + armeabi-v7a, paisagem,
   imersivo, ícone) → *Exportar projeto*.

### Testes

```bash
# Lógica (economia, construção, incubação, níveis, batalha/IA, balanceamento, expedições, save/migração)
godot --headless --path . res://tests/test_runner.tscn

# Carrega todos os scripts/cenas com os autoloads ativos (erros de parse/compilação)
godot --headless --path . res://tests/script_check.tscn

# Jogada automática do fluxo completo do 1º marco, com capturas de tela (precisa de display/Xvfb)
godot --path . -- --tour --shots=/caminho/para/capturas
```

`--tour` cria um jogo novo, constrói habitat e incubadora, incuba e choca um Rex, coloca-o no habitat,
coleta créditos, alimenta até o nível 2, vence uma batalha na Arena, volta ao parque e salva —
verificando cada etapa.

---

## Controles

| Ação | Celular | PC |
|---|---|---|
| Mover câmera | arrastar 1 dedo (com inércia) | arrastar com botão esquerdo · WASD/setas |
| Zoom | pinça | roda do mouse (zoom no cursor) |
| Selecionar criatura/prédio | tocar | clicar |
| Coletar créditos | tocar na bolha de moeda sobre o habitat | clicar na bolha |
| Construir | menu **Construir** → tocar no mapa para posicionar → ✓ verde | idem; o fantasma segue o mouse · botão direito/Esc cancela |
| Caminhos e cercas | cada toque constrói uma peça (pintura rápida) | idem |
| Fechar painel | ✕ vermelho ou tocar fora | idem · Esc |

---

## Fluxo jogável (1º marco)

Abrir jogo → carregar/criar save → parque com recursos iniciais (3.000 créditos, 150 DNA, 10 de
energia) → construir **Habitat Pré-histórico** → construir **Incubadora** → incubar (Rex 20 s,
Tricerátopo 15 s, Xenoraptor 25 s) → chocar → escolher habitat → criatura passeia no habitat →
bolha de moedas → coletar → **Alimentar** até subir de nível → **Arena** → batalha 1v1 por turnos →
recompensas → voltar ao parque → progresso salvo automaticamente.

As **missões** (rastreador no canto superior esquerdo) guiam exatamente esse caminho.

---

## Sistemas implementados

- **Parque:** mapa em `TileMapLayer` (grama, flores, terra, areia, lagos com margem autotile), árvores,
  arbustos, rochas, entrada do parque; câmera touch/mouse com limites, inércia e zoom.
- **Construção em grid (data-driven):** Caminho, Cerca, Portão, Habitat Pré-histórico, Habitat Alienígena,
  Incubadora, Centro de Pesquisa, Gerador. Fantasma com casas verdes/vermelhas, validação de
  limites/água/vegetação/sobreposição/regras (ex.: portão ao lado de cerca), custo, energia,
  limite por tipo, requisitos; caminhos e cercas conectam-se automaticamente; remoção com reembolso.
- **Energia:** capacidade fornecida pela entrada e geradores, consumida por prédios especiais.
- **Habitats:** terreno próprio, cerca, portão, comedouro, decoração, capacidade; criaturas andam, param,
  viram, descansam e escolhem novos pontos dentro dos limites. Criaturas fora da tela pausam a animação e
  atualizam a posição em passos de 0,25 s.
- **Criaturas:** `CreatureData` (espécie) × `CreatureInstance` (do jogador: UID, nível, XP, evolução, estado,
  habitat). Rex Primordial, Tricerátopo Ancestral e Xenoraptor, cada um com sprite próprio e animações
  idle/andar/ataque/dano/derrota.
- **Raridades:** Comum, Incomum, Rara, Épica, Lendária, Mítica, Anômala (força vem dos atributos, não da raridade).
- **Economia:** créditos, DNA, energia, nível do parque. Produção por intervalo com limite acumulado
  (funciona offline), bolha de coleta, números flutuantes e moedas voando até o HUD.
- **Incubadora:** escolher espécie → pagar DNA → timer persistente → chocar → escolher habitat.
- **Níveis:** até o nível 10; alimentar dá XP; atributos e renda crescem por nível; feedback visual.
- **Batalha 1v1 por turnos** (cena própria): energia (+2/rodada, máx. 10), Ataque, Defesa (prioridade,
  −60% de dano), Habilidade (2 por criatura, custo e recarga) e Reservar (+2 de energia extra);
  críticos por velocidade, dano elétrico que ignora defesa, buffs/debuffs temporários.
- **IA de batalha** por utilidade: avalia dano esperado, golpe letal, ameaça do oponente, energia,
  recargas, buffs já ativos e vida — sem escolhas aleatórias puras.
- **Arena:** escada de 5 adversários com recompensas; tela de resultado (vitória/derrota, XP, créditos, DNA).
- **Expedições:** Vale Primordial e Cratera Estelar (nível 3); recompensas sorteadas com semente salva;
  chance de amostra genética (descobre espécies).
- **Centro de Pesquisa:** sequenciar DNA (créditos → DNA) e decodificar o sinal que revela o Xenoraptor.
- **Missões:** 11 missões encadeadas que ensinam o jogo.
- **Coleção/Bestiário:** cards com sprite animado, nível, raridade, categoria; espécies não descobertas
  como silhueta; filtros por categoria.
- **Save/Load:** JSON versionado (`save_version`), migrações, escrita atômica, backup automático; saves
  corrompidos ou de versões futuras **nunca são sobrescritos** (ficam preservados em `user://`).
  Autosave a cada 20 s e ao pausar/fechar o app.
- **Áudio:** barramentos Music/SFX/UI/Creatures/Ambient; sons registrados automaticamente pelo nome do
  arquivo; o jogo funciona sem nenhum áudio.
- **Interface mobile:** tema pixel-art próprio (9-slice), botões grandes, safe areas, layout responsivo
  (16:9, 19.5:9, 20:9…), painéis animados, toasts.

## Sistemas planejados

Evolução visual/genética, formas alternativas e híbridos · habitats Aquático, Glacial, Vulcânico,
Florestal, Anômalo e Mecânico · batalhas em equipe (3v3) e PvP assíncrono · melhorias de prédios ·
visitantes do parque e satisfação · novas regiões de expedição (planetas, dimensões, oceanos, ruínas,
eventos raros) e materiais · música · localização.

---

## Estrutura do projeto

```
assets/            arte e áudio (substituíveis; mesmos nomes de arquivo = troca direta)
  creatures/ environment/ buildings/ ui/ effects/ battle/ fonts/ audio/
data/              conteúdo do jogo em Resources (.tres) — sem dados no código
  creatures/ abilities/ buildings/ habitats/ missions/ expeditions/ arena/ maps/
scenes/            main/ (boot, título) · park/ · battle/
scripts/
  core/            EventBus, GameClock, DataRegistry, SceneRouter, enums, uid, boot
  data/            classes de Resource (CreatureData, AbilityData, BuildingData…)
  economy/         Economy (créditos, DNA, nível do parque)
  creatures/       CreatureInstance, CreatureRoster, CreatureActor (IA de passeio)
  park/            ParkState (modelo), ParkMap, ParkCamera, MapLayout, park.gd (cena)
  building/        BuildController, BuildOverlay, BuildingNode, HabitatNode, IncubatorNode, fábrica
  incubation/      IncubationManager
  expeditions/     ExpeditionManager
  missions/        MissionManager
  battle/          regras, combatente, resolvedor, IA, ArenaManager, cena e HUD da batalha
  save/            SaveManager, SaveMigrations
  audio/           AudioManager
  ui/              tema, kit de UI, HUD, painéis (ui/panels/)
resources/         bus de áudio
tests/             testes headless, checagem de scripts, tour automático
tools/             geradores de arte (Python + Pillow), sons e mapa
docs/              ADDING_CONTENT.md — como adicionar criaturas, prédios, habilidades, missões, habitats
```

**Arquitetura:** os *autoloads* guardam o estado (cada um com uma responsabilidade e `to_dict/from_dict`);
as cenas apenas desenham esse estado e podem ser recriadas a qualquer momento. A comunicação entre
sistemas passa pelo `EventBus` (ex.: missões e autosave escutam eventos, sem acoplamento direto).
A lógica de batalha é pura (sem nodes) e testada headless.

### Regerar assets

```bash
pip install pillow
python3 tools/art/gen_all.py   # todos os sprites, tiles, ícones e efeitos
python3 tools/gen_sfx.py       # efeitos sonoros
python3 tools/gen_map.py       # mapa inicial (data/maps/park_start.txt — editável à mão)
```

Para trocar por arte definitiva, basta substituir os PNGs mantendo o nome (e o layout das folhas de
sprite descrito em `docs/ADDING_CONTENT.md`).
