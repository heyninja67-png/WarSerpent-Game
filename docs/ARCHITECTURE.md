# Arquitetura — War Serpent.io

## Entrada e estados de interface

`project.godot` aponta para `scenes/Main.tscn`, um `Control` com `scripts/ui/Main.gd`. A interface é construída por componentes Godot reais: botões, painéis, opções, campos de nome e confirmação de compras. `SerpentPreview.gd` anima os sprites da skin selecionada no menu e na coleção.

`Main.gd` coordena splash, carregamento por `ResourceLoader`, menu, páginas de progressão, `ArenaGame` e resultados. Recebe o sinal `finished(result)` da arena, remove a instância terminada e chama `PlayerProfile.record_run()` uma única vez. Partidas abandonadas voltam ao menu sem recompensa.

O canvas lógico permanece 1280×720 com aspecto preservado. A interface não exige coordenadas do tamanho físico do aparelho. Landscape e GL Compatibility são configurados no projeto; package e arquiteturas estão no preset Android.

## Simulação e apresentação

| Arquivo | Responsabilidade |
|---|---|
| `scripts/movement/snake_model.gd` | Estado de cada cobra; trajetória, corpo, massa, direção, velocidade, boost, crescimento, temporizadores e proteção |
| `scripts/gameplay/ArenaGame.gd` | Ciclo da arena, coleta, resolução de colisões, efeitos de poderes, bots, câmera, desenho e controles |
| `scripts/gameplay/spatial_hash.gd` | Índice espacial para candidatos próximos de alimento e corpo |
| `scripts/bots/arena_brain.gd` | Decisões periódicas de procura, perseguição, evasão, boost e habilidade |
| `scripts/ui/SerpentPreview.gd` | Prévia animada das cinco identidades visuais |

O corpo é reconstruído amostrando uma trajetória por distância, com espaçamento consistente; não depende de copiar a posição do segmento anterior a cada frame. O modelo limita mudanças de direção e mantém massa mínima durante o boost. Partículas coletadas aumentam massa e pontuação.

A física avança em `_physics_process`; câmera e atualização visual ficam em `_process`. Cabeças são verificadas contra candidatos do índice corporal, sem colisão com o próprio corpo. Encontros entre cabeças seguem as regras de proteção de cada participante. A borda é letal mesmo com escudo ou forma espectral.

Os cinco poderes são selecionados pela skin no modelo; os efeitos de área e rastros são aplicados pela arena. A arquitetura tem módulos separados, mas habilidades ainda usam ramificações pelos cinco IDs. Uma coleção maior deve primeiro extrair uma interface de habilidades e substituir esses limites fixos.

## Entrada e ciclo Android

Joystick, boost e poder possuem IDs de toque separados, permitindo direção, aceleração e habilidade simultaneamente. O computador usa o mesmo caminho de interface, mais WASD/setas, Espaço, E e Esc/P. Pausar congela a simulação; a apresentação continua disponível para retomar ou abandonar. O callback Android de suspensão pausa uma arena ativa.

O jogo não abre conexão com servidores. Ranking competitivo é calculado entre as cobras da partida; o registro do menu mostra o recorde local do perfil.

## Dados, economia e save

`scripts/core/Profile.gd` expõe `PlayerProfile`, um `RefCounted`. `data/catalog.json` fornece nomes, preços, raridades, descrições e metadados dos cinco poderes. O JSON precisa ser incluído no preset de exportação, pois é lido por `FileAccess`, não como uma cena importada.

Compras validam ID, saldo e propriedade; equipar exige posse. Operações salvam imediatamente e revertem a mutação em memória quando a escrita falha. O resultado da partida produz coins e XP a partir de pontuação, tempo e eliminações; eliminações também rendem fragments. Missões e conquistas usam estatísticas acumuladas. A recompensa diária compara a data UTC do dispositivo e, por ser totalmente local, não possui proteção contra mudança do relógio.

O save usa `user://profile.json`, schema versão 1. Uma escrita temporária é descarregada e renomeada; o primário válido anterior é preservado em `.bak`. Ao abrir, o perfil tenta o primário e depois o backup. Versões de schema futuras não são sobrescritas por este cliente. O arquivo é local e editável: não há autenticação, antitrapaça ou sincronização.

## Recursos e otimização existente

Os sprites de cabeça, corpo e cauda, logotipos, botões, ícones, chão e efeitos são arquivos PNG reais. O fundo é key art original gerada para o projeto. O áudio foi sintetizado e salvo em WAV. Fontes e avisos legais estão em `assets/fonts/` e `assets/LICENSE.md`.

A arena reutiliza entradas de alimento, limita partículas transitórias, elimina desenhos fora da câmera, usa hashing espacial e limita a frequência de decisões de IA. O perfil Baixo reduz bots/alimentos/efeitos e limita a atualização visual a 30 FPS; Médio e Alto usam limite de 60 FPS, com brilho adicional em Alto. Auto seleciona o orçamento Baixo se o sistema informar menos de quatro processadores lógicos; caso contrário, usa Médio. É uma heurística de CPU, não um benchmark da GPU. Esses números são metas configuradas, não resultados medidos em hardware Android. Não há atlas empacotado nem sistema completo de pooling de todos os efeitos nesta versão.

## Construção e validação

`tools/setup_android.sh` prepara somente ferramentas ausentes em diretórios locais, verifica arquivos oficiais e escreve os caminhos em preferências Godot externas ao checkout. O APK é exportado a partir do template oficial compatível, sem Gradle. A chave de desenvolvimento também fica fora do repositório.

`tools/build_android.sh` gera e inspeciona o APK. `tools/test.sh` importa o projeto e executa testes unitários/de integração em diretório temporário isolado. `BUILD_REPORT.md` registra resultados efetivos da entrega. SDK, templates, chaves, caches e saves não fazem parte do arquivo-fonte distribuído.
