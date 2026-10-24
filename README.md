# War Serpent.io — Emnio

Jogo 2D de arena de serpentes para Android, com identidade cyberpunk, progressão local e adversários controlados por IA. Esta entrega é uma versão vertical jogável offline: splash → carregamento de recursos → menu → arena → derrota → resultados → reinício.

![Menu de War Serpent.io](docs/screenshots/menu.png)

## Entrega e compatibilidade

| Item | Configuração |
|---|---|
| Engine | Godot 4.6.3, GDScript, GL Compatibility |
| Aplicativo | War Serpent.io / Emnio |
| Package | `com.emnioggs.warserpent` |
| Versão | `1.0.0`, version code `1` |
| Android | Android 7.0/API 24 ou superior; target API 36 do template Godot |
| Arquiteturas | ARMv7 e ARM64 |
| GPU | OpenGL ES 3 compatível |
| Tela | Landscape, canvas 1280×720 preservado em outras proporções |
| Rede | Offline; sem permissão de Internet, anúncios ou pagamentos reais |

O APK de desenvolvimento fica em `builds/WarSerpentIO-debug.apk`. O código completo está em `builds/WarSerpentIO-Source.zip`. Consulte [BUILD_REPORT.md](BUILD_REPORT.md) para o resultado efetivo da compilação, verificações do pacote e limitações de testes Android.

## Sistemas implementados

- Splash Emnio animada e carregamento cuja barra acompanha tarefas reais de recursos.
- Menu com prévia animada da cobra equipada, perfil, XP, nível e moedas; coleção, loja com confirmação de compra, missões, carga diária, registro local, conquistas e ajustes.
- Arena Neon City com movimento contínuo em 360°, corpo reconstruído pela distância percorrida, coleta, crescimento, câmera dinâmica, boost com gasto de massa e colisões cabeça/corpo.
- Bots que procuram alimento, antecipam ameaças, evitam bordas e usam boost e habilidades; três dificuldades e classificação durante a partida.
- Cinco cobras com sprites próprios de cabeça, corpo e cauda, poderes com duração/cooldown e efeitos reais sobre a simulação.
- HUD, joystick, boost e poder com identificação independente de toques; pausa, derrota, recompensas e reinício.
- Perfil persistente com JSON versionado, gravação atômica, backup, recuperação de arquivo corrompido e proteção de saves de versões futuras.
- Áudio sintetizado original, texturas e ícones próprios; qualidade Baixo, Médio, Alto e Auto.

| Cobra | Raridade | Poder | Preço em coins |
|---|---|---|---:|
| Volt Serpent | Comum | Electric Overdrive: velocidade temporária | Inicial |
| Inferno Viper | Incomum | Flame Burst: desaceleração de inimigos próximos | 150 |
| Frost Fang | Rara | Frozen Trail: rastro que desacelera oponentes | 250 |
| Cyber Reaper | Épica | Cyber Shield: absorve uma colisão elegível | 400 |
| Shadow Phantom | Lendária | Phantom Shift: proteção espectral temporária | 600 |

A borda da arena continua letal durante poderes. O perfil começa com 500 coins e 25 gems. Coins compram skins; gems e fragments são salvos e recebidos como recompensas, mas ainda não possuem um mercado próprio. O ranking do menu registra o recorde desta instalação; não é um ranking online.

## Abrir e jogar no computador

Instale o editor Godot **4.6.3**, importe `project.godot` e pressione **F5** para executar o projeto. A cena de entrada é `scenes/Main.tscn`. Pelo terminal, na raiz:

```sh
godot --path .
```

| Ação | Android | Computador |
|---|---|---|
| Direção | Joystick inferior esquerdo | WASD, setas ou arrastar o joystick com o mouse |
| Aceleração | Segurar BOOST | Segurar Espaço ou o botão BOOST |
| Habilidade | Botão de poder | E ou botão de poder |
| Pausa | Botão superior; Voltar do Android | Esc/P ou botão superior |

O corpo segue a direção atual quando o joystick é solto. O boost exige massa suficiente. Na pausa é possível continuar ou abandonar; abandonar não concede recompensas de uma partida concluída.

Os saves ficam no diretório `user://` do Godot, isolado por aplicativo. Desinstalar o APK pode apagar esses dados. O jogo não sincroniza progresso com servidores.

## Preparar e compilar Android

No ambiente Linux usado nesta entrega, Godot e Java já estavam disponíveis. O SDK não foi localizado na inspeção inicial; os componentes ausentes e templates foram instalados em diretórios locais. Nenhuma instalação global foi substituída. Veja [docs/toolchain_notes.md](docs/toolchain_notes.md) e [docs/sdk_notes.md](docs/sdk_notes.md) para versões, origens e checksums.

Requisitos: Godot 4.6.3, Python 3, Java com `java` e `keytool`, conectividade HTTPS para obter apenas ferramentas ausentes, e um diretório de trabalho gravável. O exportador usa o template APK pré-compilado do Godot; não depende de Gradle, `javac` ou NDK.

```sh
cd /workspace/WarSerpent-Game
./tools/setup_android.sh
./tools/build_android.sh
```

`setup_android.sh` reutiliza `ANDROID_HOME`/`ANDROID_SDK_ROOT` quando fornecidos, instala os pacotes Android ausentes, verifica os arquivos oficiais e configura os caminhos Android no arquivo local de preferências do editor. O padrão de ferramentas é `/workspace/toolchains`; a chave de depuração fica fora do projeto.

`build_android.sh` importa os recursos, executa a exportação Android, corrige uma authority AndroidX duplicada do exportador Godot, alinha e assina novamente, verifica assinatura e consulta o manifesto com `aapt`, verifica alinhamento e imprime SHA-256. A exportação central é:

```sh
godot --headless --path . --export-debug Android builds/WarSerpentIO-debug.apk
```

Em outra máquina, informe caminhos graváveis antes dos scripts, por exemplo:

```sh
export WARSERPENT_TOOLCHAINS="$PWD/../warserpent-toolchains"
export ANDROID_HOME="$WARSERPENT_TOOLCHAINS/android-sdk"
export XDG_CONFIG_HOME="$PWD/../warserpent-local/config"
export XDG_DATA_HOME="$PWD/../warserpent-local/data"
export XDG_CACHE_HOME="$PWD/../warserpent-local/cache"
./tools/setup_android.sh
./tools/build_android.sh
```

O APK é assinado para desenvolvimento e instalação manual em aparelho próprio. Não é uma entrega de loja. Uma publicação exige assinatura privada de release, revisão de políticas, validação em aparelhos e preparação de distribuição. Nenhuma chave privada está incluída no ZIP.

Com um dispositivo autorizado por USB, é possível instalar e abrir:

```sh
"$ANDROID_HOME/platform-tools/adb" install -r builds/WarSerpentIO-debug.apk
"$ANDROID_HOME/platform-tools/adb" shell am start -n com.emnioggs.warserpent/com.godot.game.GodotAppLauncher
```

Esses comandos de instalação só devem ser tratados como executados quando constarem no relatório com um dispositivo disponível.

## Testes

```sh
./tools/test.sh
```

O runner cria um diretório exclusivo em `/tmp/warserpent-flow-tests.*`, importa os recursos e executa as três suítes com Godot headless. Saves de jogador ficam preservados; logs são mantidos no diretório informado ao terminar. `set -euo pipefail` preserva falhas dos processos mesmo com captura por `tee`.

| Suíte | Verificações | Cobertura |
|---|---:|---|
| `tests/test_profile.gd` | 45 | Economia, inventário, compras duplicadas, missões, XP, configurações, persistência e recuperação |
| `tests/test_gameplay.gd` | 34 | Movimento, espaçamento, crescimento, boost, poderes, cooldowns, colisões e IA |
| `tests/test_flow.gd` | 79 | Splash, recursos, navegação, compras, toques simultâneos, arena, derrota, resultados e reinício |

Para rodar a integração separadamente, proteja o save com o prefixo exigido pelo próprio teste:

```sh
XDG_DATA_HOME=/tmp/warserpent-flow-manual godot --headless --path . --script tests/test_flow.gd
```

Capturas reais renderizadas em desktop com llvmpipe, em 1280×720, estão em `docs/screenshots/`; `tests/capture_screens.gd` e `tools/start_display.sh` auxiliam sua reprodução no ambiente de nuvem com Xvfb. O servidor de testes usa saída de áudio Dummy; não foi realizado teste auditivo em hardware. Testes headless e desktop não substituem execução no Android, verificação de touchscreen físico, consumo de bateria ou medições de FPS.

## Modificar e expandir

Consulte [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md). As definições de coleção estão em `data/catalog.json`; arte reprodutível e áudio em `tools/generate_assets.py` e `tools/generate_audio.py`. A prévia de UI e o gameplay carregam os mesmos sprites de `assets/snakes/`.

Os PNG/WAV finais já estão incluídos e dispensam ferramentas de geração para abrir ou compilar. Para regenerar a arte programática, use Python 3 com Pillow e fontes DejaVu instaladas nos caminhos Linux usados pelo script; o sintetizador de áudio usa somente a biblioteca padrão. O gerador não recria nem modifica o fundo de menu produzido por geração de imagem.

O catálogo pode receber novos dados, mas adicionar uma sexta cobra também exige ampliar os limites e implementar sua habilidade nos scripts. A versão atual não promete 50 skins prontas. [docs/ROADMAP.md](docs/ROADMAP.md) separa o que existe dos próximos passos.

O ZIP contém fontes, cenas, dados, testes, assets e documentação; não inclui SDK, templates de exportação, cache `.godot`, saves pessoais ou keystores. O Godot recria os imports ao abrir o projeto.

## Licenças

Código e documentação: [MIT, © 2026 Emnio](LICENSE). Assets originais e áudio: [proveniência e licença separada](assets/LICENSE.md), incluindo o fundo gerado para o projeto. As fontes DejaVu conservam sua licença em `assets/fonts/LICENSE-DejaVu.txt`. A engine Godot e as ferramentas Android têm licenças próprias, documentadas em [docs/THIRD_PARTY.md](docs/THIRD_PARTY.md). Não foram incorporados assets ou código de Slither.io/Snake.io.
