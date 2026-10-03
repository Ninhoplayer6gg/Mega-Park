# Changelog

Todas as mudanças relevantes do Mega Park. Formato inspirado em [Keep a Changelog](https://keepachangelog.com/pt-BR/).

## [0.1.1] — Revisão visual: zero placeholders

### Alterado
- Barras de progresso, slider, barras de rolagem, pílulas de recursos, selos de raridade/efeitos e o
  contador de missões agora usam molduras 9-slice em pixel art (antes eram retângulos lisos).
- Células de energia da batalha, barra de incubação no parque e marcadores de grade do modo construção
  redesenhados em pixel art.
- Logotipo "MEGA PARK" e emblema "VS" desenhados em pixel art (antes eram texto).
- Espécies não descobertas: cartão de mistério com fundo de DNA/estrelas, brilho ciano no contorno e
  "?" animado (antes, silhueta simples).
- Expedições com ilustrações próprias de cada região (Vale Primordial, Cratera Estelar).
- Ícones dedicados no menu Construir para os habitats e para a incubadora completa (cúpula + ovo).
- Manchas de terra com bordas orgânicas (autotile) em vez de retângulos.
- Chão do Habitat Alienígena mais claro (regolito com crateras e musgo ciano) para destacar a criatura.
- Lagos com vitórias-régias e juncos; ícones próprios para os filtros de categoria.
- Nomes longos quebram linha nos cards; selo de raridade não é mais cortado na incubadora.

### Adicionado
- `docs/ADDING_CONTENT.md`: padrão visual obrigatório e checklist anti-placeholder.
- Tour automático cobre todas as telas (configurações, pesquisa, gerador, habitat alienígena, batalha
  com Xenoraptor, recompensas).

## [0.1.0] — Primeira versão jogável

### Adicionado
- Projeto Godot 4.3 (GL Compatibility), paisagem, focado em Android e jogável no PC.
- Parque em `TileMapLayer` gerado a partir de um mapa ASCII editável (`data/maps/park_start.txt`):
  grama, flores, terra, areia, lagos com margens autotile (incluindo cantos côncavos), árvores, cicas,
  arbustos, rochas e entrada do parque.
- Câmera touch (arrastar com inércia, pinça) e PC (mouse, scroll, WASD).
- Sistema de construção em grid totalmente data-driven: 8 prédios construíveis, fantasma com
  validação por casa, regras de posicionamento, energia, limites, requisitos, peças autoconectáveis,
  remoção com reembolso.
- Habitats Pré-histórico e Alienígena com cerca, portão, comedouro, decoração, capacidade e criaturas
  passeando (IA de passeio leve, com otimização fora da tela).
- Criaturas Rex Primordial, Tricerátopo Ancestral e Xenoraptor (`CreatureData` + `CreatureInstance`),
  7 raridades, níveis 1–10, alimentação/XP.
- Economia: créditos, DNA, energia, nível do parque; produção com limite e coleta por bolha.
- Incubadora com timers persistentes e escolha de habitat.
- Centro de Pesquisa (sequenciador de DNA, descoberta do Xenoraptor) e Gerador de Energia.
- Batalha 1v1 por turnos em cena própria: energia, Ataque/Defesa/Habilidade/Reservar, 6 habilidades
  originais, buffs/debuffs, críticos, IA por utilidade, Arena com 5 adversários e tela de resultado.
- Expedições (Vale Primordial, Cratera Estelar) com recompensas determinísticas por semente.
- 11 missões tutoriais com rastreador no HUD.
- Coleção e Bestiário com silhuetas e filtros por categoria.
- Save JSON versionado com migrações, escrita atômica, backup e preservação de saves inválidos;
  autosave periódico e ao pausar/fechar.
- AudioManager com barramentos e registro automático de sons; 22 efeitos sonoros sintetizados originais.
- Interface mobile com tema pixel-art próprio, safe areas e layout responsivo.
- Arte original gerada por código (`tools/art/`): criaturas com 5 animações e sombreamento em
  4 tons com variação de matiz, textura de escamas, tiles, prédios, ícones, efeitos e arena.
- Testes headless (130+ verificações), checagem de scripts e tour automático com capturas de tela.
- Documentação: README e `docs/ADDING_CONTENT.md`.
