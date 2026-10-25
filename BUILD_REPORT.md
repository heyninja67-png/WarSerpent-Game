# War Serpent.io 1.2.1 — Emnio Games

Application ID: `com.emnioggs.warserpent`. Versão1.2.1, version code4. APK Android nativo exportado em modo release otimizado, com a mesma assinatura das versões anteriores.

## Pedido e resultado

O usuário preferiu as cobras anteriores e identificou elementos cortados/sobrepostos. Esta atualização restaura as cobras clássicas e corrige causas concretas de geometria, navegação e toque, preservando o lobby de jogo, START dourado, minimapa, piso roxo, música, oito poderes e marca Emnio Games.

### Cobras restauradas

Todos os24PNG de cabeça/corpo/cauda das oito skins foram restaurados **byte por byte** do commit `e31130e13de1bd6b8ebee193da3f64602aa14b5d` (v1.1). Os hashes de cada arquivo coincidem. Os outros50PNG foram verificados e permanecem iguais à v1.2.

O gerador restrito `tools/generate_classic_snakes.py` reproduziu os24 originais em duas execuções; o ponto de entrada legado também foi verificado. A geração principal não recria o visual arredondado descartado. Provas: [assets/snakes/RESTORE_PROOF.json](assets/snakes/RESTORE_PROOF.json), `SHA256SUMS` e README dessa pasta.

### Bugs de interface corrigidos

- Bordas de textura eram herdadas como padding de conteúdo: botões cresciam até51/63px além do tamanho pedido. O botão de modo sobrepunha o título e EQUIPPED ultrapassava o card em6px. Conteúdo e bordas agora possuem margens independentes.
- Nomes longos expandiam o botão de perfil sobre o XP. O botão mantém sua área e usa reticências; o nome completo continua no perfil/tooltip.
- Valores grandes eram cortados. Títulos e números ajustam a fonte dentro do espaço disponível, preservando valores exatos nas telas de perfil/resultados.
- O fundo continuava1280×720 quando a janela passava a1600×720, deixando área descoberta. O layout agora responde ao resize real, sem reconstruir a página ou apagar texto ainda não salvo.
- Páginas antigas permaneciam visíveis por um frame, e o menu aparecia por trás de textos das páginas. A página modal é opaca, o conteúdo anterior é ocultado e bloqueado imediatamente.
- Confirmações de compra sobreviviam à navegação. Voltar cancela primeiro o diálogo, navegação invalida callbacks antigos e não é possível comprar por uma confirmação abandonada.
- A remoção síncrona de nós durante um clique provocava erro nativo `can_process`. Nós são ocultados/desativados imediatamente e liberados no fim do frame, preservando a segurança do dispatcher.
- Avisos transitórios saíram da área de START/compra e não interceptam o toque.
- No HUD, nomes largos e pontuações não invadem colunas vizinhas; nomes usam largura real em pixels e scores grandes recebem formato compacto alinhado à direita.
- As duas áreas de BOOST agora mantêm proprietários de toque independentes. Soltar uma não cancela a outra ainda pressionada; pausa/foco limpa todas corretamente.
- O ranking ordenava referências em cache e desenhava pontuações atualizadas fora dessa ordem. Ordem, nomes e scores agora fazem parte do mesmo snapshot de atualização.

Reprodução anterior dos bugs: [docs/ui-before-fix.txt](docs/ui-before-fix.txt), [docs/boost-before-fix.txt](docs/boost-before-fix.txt). O segundo mostra a regressão de BOOST falhando antes da correção; os testes posteriores passam.

### Mais animação

Entradas escalonadas por transparência mantêm os hitboxes no lugar. A cobra troca suavemente no mesmo lobby, com cancelamento de transições anteriores e seleção final consistente. Há parallax leve com margem de segurança, cards animados, pulso de habilidade pronta, reserva de boost suavizada e pop de score. Resultados contam até a pontuação e recompensas reais; a animação não altera economia nem concede recompensas novamente.

Animações são limitadas/vinculadas aos nós e canceladas na navegação. Recursos instanciados, caches e limite de24Hz para prévias/efeitos de menu foram preservados. Não foram adicionados draw calls para as novas animações do HUD.

[Prévia animada real](docs/screenshots/lobby_animated.gif):36 framebuffers capturados do jogo em execução,3s,12quadros/s,768×432 após conversão. Isso é uma gravação de desktop e não uma medição de FPS Android.

## Verificações executadas

`./tools/test.sh` executa import e suites com dados temporários isolados. A suíte de interface recebeu uma última asserção adicional sobre o valor intermediário da animação e foi repetida. Os resultados finais por componente são:

| Componente | Aprovadas |
|---|---:|
| Perfil/economia/migração |79|
| Gameplay, geometria do HUD e controles |95|
| Fluxo de UI, geometria, ponteiro, resize e animações |242|
| Dois processos OS com UDP real |25|
| **Total final** |**441**|

Zero falhas nos resultados finais; nenhum ERROR/WARNING no fluxo final de UI. [docs/test-results.txt](docs/test-results.txt) reúne os resultados finais reais; `docs/test-results-aggregate.txt` preserva a execução agregada anterior à última asserção extra.

A geometria foi medida com as fontes reais: clipping de glifos, interseção de controles importantes, limites de cards, hover/press, entrada de página, valores máximos, formulários/popups e proporções1280×720/1600×720/1280×900. Os eventos de toque/ponteiro passam pelo dispatcher. Há uma asserção explícita de conclusão de todo o stress para impedir resultado parcial falso após erro de coroutine.

Cinco capturas reais em [docs/screenshots](docs/screenshots) confirmam cobras clássicas, ausência de texto fantasma, botões dentro dos cards, modo separado do título e valores finais corretos. Captura terminou sem erros/vazamentos; o driver virtual informa apenas que não pode alterar V-Sync.

## APK

Build real e validação independente:

```sh
./tools/build_android.sh
python3 tools/validate_android.py
```

Passaram146 verificações dos recursos extraídos do APK, incluindo as marcas, piso,24sprites clássicos decodificados, fontes, músicas, código compilado e configurações. A prova canônica de hashes das cobras também é verificada dentro do pacote.

- Package e versão: `com.emnioggs.warserpent`,1.2.1/code4.
- Android7/API24+, target API36, ARM64/ARMv7, GLES3, landscape/edge-to-edge.
- Template release oficial; não debuggable; bibliotecas nativas idênticas ao template.
- Assinatura v2/v3 válida, mesmo certificado original e alinhamento16KB ARM64.
- INTERNET para multiplayer; sem câmera, microfone ou armazenamento externo.
- Arquivo local histórico `builds/WarSerpentIO-debug.apk` contém build release; download versionado `WarSerpentIO-v1.2.1.apk`.

Hash, tamanho e evidências exatas: [docs/apk_validation.txt](docs/apk_validation.txt), [docs/android_v1_2_1_validation.md](docs/android_v1_2_1_validation.md). A chave privada permanece fora do checkout/ZIP. SDK e ferramentas existentes foram reutilizados, sem reinstalação.

## Limitações e instalação

Não há aparelho ou emulador Android conectado. Instalação, toque físico, teclado do sistema, recortes específicos de cada fabricante, FPS/GPU/bateria e Wi-Fi real não foram testados nesta máquina. A correção foi validada por execução headless, renderização desktop e inspeção do APK. Não se promete que todos os problemas de um aparelho estejam resolvidos.

Instale por cima da versão anterior, sem desinstalar primeiro, para manter os dados. A identidade e o incremento de versão foram verificados; a atualização física `adb install -r` não foi executada.

Multiplayer continua por conexão direta, sem servidor público/matchmaking automático. Os arquivos e saves são preservados; modelos físicos e habilidades não foram alterados neste patch.

## Fonte e licenças

ZIP completo com código, arte, geradores, testes, capturas e documentação. SDK, templates, caches, saves e keystores são excluídos. Código MIT; arte/áudio conforme [assets/LICENSE.md](assets/LICENSE.md); fontes DejaVu e Godot mantêm seus avisos. O pacote fonte é verificado por CRC/conteúdo e por nova importação/execução de uma cópia extraída.

Uma cópia extraída do ZIP, sem caches, passou novos imports e242 verificações de fluxo com saída0 e sem erros. Evidência em `docs/source-archive-validation.txt`.
