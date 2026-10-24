# War Serpent.io — relatório de desenvolvimento e compilação

Data: 24 de outubro de 2026. Estúdio: **Emnio**. Versão **1.0.0**, código **1**.

## Resultado

Foi criado e executado um jogo Godot 2D offline com fluxo completo, e foi realmente gerado um APK Android de desenvolvimento. Não é um APK vazio nem uma aplicação HTML. O código completo, cenas, assets originais, testes e ferramentas de compilação estão no ZIP open source.

- APK: `builds/WarSerpentIO-debug.apk`.
- Fontes: `builds/WarSerpentIO-Source.zip`.
- Instruções: [README.md](README.md).
- Package: **com.emnioggs.warserpent**.
- Tela: horizontal, canvas 1280×720 com preservação de proporção.
- Compatibilidade declarada: Android 7/API 24+, ARM64/ARMv7, OpenGL ES 3. Target API 36.
- SHA-256 e tamanho final do APK: [docs/apk_validation.txt](docs/apk_validation.txt). Checksums da entrega: `builds/SHA256SUMS`.

Compilar, verificar a assinatura e executar em desktop não comprova instalação ou funcionamento em todos os aparelhos Android. Não havia aparelho ou emulador conectado.

## Ferramentas e decisão de engine

| Ferramenta | Versão / uso |
|---|---|
| Godot | 4.6.3 stable, revisão oficial 7d41c59c4 |
| Renderer | GL Compatibility |
| Java | OpenJDK runtime 21.0.12.1; java e keytool existentes |
| Build Tools Android | 35.0.1: aapt, apksigner, zipalign |
| SDK Platform | API 35, revisão 2, local |
| Template Android Godot | 4.6.3 oficial; binário pré-compilado com min24/target36 |
| Platform Tools | 37.0.1, adb 1.0.41 |
| Execução renderizada | Xvfb + Mesa llvmpipe, desktop Linux |

O SDK não estava nas variáveis ou diretórios pesquisados, embora a solicitação presumisse sua existência. Apenas componentes ausentes foram instalados em `/workspace/toolchains`. O Godot já estava disponível. Templates foram obtidos da versão oficial e verificados por SHA-512; arquivos Google foram verificados contra checksums oficiais. TLS e verificação de integridade permaneceram ativos.

A exportação direta com templates Android funciona sem Gradle, `javac`, NDK ou compilação da engine. O Java existente foi suficiente. O target36 vem do template pré-compilado; as ferramentas35.0.1 foram aceitas e o manifesto final foi inspecionado. Fontes e detalhes: [toolchain_notes.md](docs/toolchain_notes.md), [sdk_notes.md](docs/sdk_notes.md).

## Sistemas implementados

| Sistema | Implementação entregue |
|---|---|
| Inicialização | Splash Emnio com pulso e passagem de serpente; marca do jogo; progresso de tarefas reais de carregamento |
| Menu | Cobra equipada animada, nome, nível, XP, moedas/gemas, seleção de dificuldade e todas as telas de navegação funcionais |
| Movimento | Direção contínua 360°, limite de giro, histórico interpolado por distância, crescimento e corpo contínuo com sprites |
| Arena | Neon City 2800×2800, piso, energia, borda letal, câmera com zoom suave |
| Boost | Velocidade aumentada, consumo de massa, energia descartada, feedback visual e sonoro |
| Colisão | Cabeça/corpo, cabeça/cabeça, imunidade de entrada, escudo consumível; borda sempre letal |
| IA | Busca de energia, desvio de ameaças/bordas, decisão de perseguição/fuga, boost e poderes, três dificuldades |
| Habilidades | Volt: velocidade; Inferno: lentidão próxima; Frost: trilha lenta; Cyber: absorção de colisão; Shadow: proteção espectral finita |
| HUD | Joystick, boost, habilidade/cooldown, score, comprimento, eliminações, tempo e classificação contra bots |
| Partida | Pausa, derrota animada, energia liberada, resultados, recompensas, reinício e retorno ao menu |
| Economia | Coins, gems, fragments; compras de skins com confirmação e saldo real; inventário e equipamento |
| Progressão | XP/nível, quatro missões, quatro conquistas, caixa diária com bloqueio de duplicação |
| Save | JSON versionado, escrita atômica, backup, recuperação e proteção de versões futuras |
| Configurações | Som, qualidade e dificuldade; nome editável; créditos/licença Godot acessíveis no APK |

Cinco skins entregues: **Volt Serpent, Inferno Viper, Frost Fang, Cyber Reaper, Shadow Phantom**. Raridades em uso: Comum, Incomum, Rara, Épica e Lendária. Durações e cooldowns reais estão alinhados com `data/catalog.json`.

O perfil começa com 500 coins. A carga diária concede 75 coins, 3 gems e 2 fragments uma vez por dia UTC. Coins compram skins; gems/fragments são contabilizados, sem mercado próprio nesta versão. Não há pagamentos, anúncios, servidores, multiplayer ou ranking online.

## Arte, áudio e licenciamento

Foram produzidos 42 PNGs próprios, incluindo logos, ícone Android, cinco conjuntos de cabeça/corpo/cauda, UI, joystick, poderes, baú, moedas, arena e efeitos. O fundo original foi gerado com a ferramenta de geração de imagens disponível. A integração Adobe não estava disponível nesta sessão.

Há sete WAVs sintetizados: toque, coleta, boost, habilidade, derrota, desbloqueio e ambiente. A reprodução foi exercitada pela engine com driver Dummy no servidor; não houve avaliação auditiva por dispositivo de saída.

Código: MIT. Arte autoral e áudio: CC0 conforme [assets/LICENSE.md](assets/LICENSE.md). Fontes DejaVu têm sua licença preservada. A licença Godot está em [THIRD_PARTY.md](docs/THIRD_PARTY.md) e acessível na tela de créditos. Não foram usados assets de Slither.io/Snake.io.

## Testes efetivamente executados

Comando: `./tools/test.sh`. Os testes usam diretórios temporários isolados e preservam o código de saída dos processos.

| Suíte | Resultado | Evidência |
|---|---|---|
| Perfil/economia | 45 verificações, zero falhas | Compras, propriedade, saldo, XP, missões, caixa diária, backup e saves |
| Gameplay | 34 verificações, zero falhas | Movimento, espaçamento, crescimento, massa, cinco poderes, cooldowns, colisões e IA |
| Integração | 79 verificações, zero falhas | Fluxo completo, navegação, compra, licença, inputs simultâneos, morte, resultados, reinício e persistência |
| Simulação prolongada | Cinco skins, 6.571 passos, zero falhas | [gameplay_validation.md](docs/gameplay_validation.md) |
| Renderização real desktop | Quatro capturas 1280×720, saída 0 | [screenshots](docs/screenshots/) |

**Total das três suítes: 158 verificações aprovadas.** Log: [test-results.txt](docs/test-results.txt). A simulação medida no servidor consumiu cerca de 0,964 ms por passo; isso não representa FPS Android.

Os toques foram injetados pelo dispatcher real `Input.parse_input_event` com transformação de coordenadas, incluindo joystick, boost e poder simultâneos. Não são testes de touchscreen físico.

As capturas foram obtidas do framebuffer Godot, não montagens de UI. A inspeção corrigiu textos que ultrapassavam cards. O encerramento renderizado foi validado sem vazamentos de objetos/recursos após liberar os streams e aguardar o mixer. O driver virtual informa que não pode alterar V-Sync; esse aviso não é erro de script.

## Compilação Android e verificação do pacote

```sh
./tools/setup_android.sh
./tools/build_android.sh
```

O helper importa recursos e executa:

```sh
godot --headless --path . --export-debug Android builds/WarSerpentIO-debug.apk
```

Depois corrige uma duplicação de autoridades de providers produzida pelo exportador direto Godot4.6.3, alinha e assina novamente com a chave local de desenvolvimento. A correção AXML é limitada ao provider AndroidX: testa package, semântica, idempotência, CRC e igualdade dos demais payloads. Não altera código do jogo nem desativa verificação de assinatura.

Validações executadas com as ferramentas Android e análise ZIP/ELF:

- APK existente, tamanho plausível, CRCs válidos e DEX executável.
- Manifesto binário legível; package, label, versão, orientação, SDKs e providers verificados.
- Scripts GDScript compilados, cena principal, catálogo JSON e recursos importados presentes.
- Assinaturas v2 e v3 válidas; chave privada fora do projeto/ZIP.
- ARM64 e ARMv7 incluídos; `zipalign -c -P 16 4` aprovado.
- Segmentos ELF ARM64 com alinhamento de 16 KB; sem permissões Android opcionais ou Internet.

O relatório de verificação exato está em [apk_validation.txt](docs/apk_validation.txt). O log completo da exportação é mantido na máquina em `builds/android-build.log`.

## Otimização e limites

Há spatial hashing para consulta de comida/corpos, culling de sprites, limite de partículas, energia reaproveitada e histórico de movimento limitado. Baixo reduz objetos/efeitos e limita a meta a 30 FPS. Médio/Alto usam meta de 60; Alto acrescenta brilho. Auto escolhe orçamento pela contagem de CPUs, uma heurística simples, sem medir GPU.

**Não foram medidos FPS, memória, temperatura, consumo de CPU/GPU ou bateria em Android.** Não há garantia de 30/60 FPS em aparelhos. Atlases, pooling adicional e otimização guiada por profiler continuam no roadmap.

Pendências de expansão: skins adicionais, raridades Mítica/Divina, mais arenas, poderes orientados inteiramente por dados, mercado de gems/fragments, acessibilidade e multiplayer. O catálogo atual suporta cinco tipos; chegar a 50+ exige ampliar os limites e a arquitetura, não apenas adicionar nomes ao JSON. Consulte [ROADMAP.md](docs/ROADMAP.md).

## Distribuição e próximos testes

`adb devices -l` foi executado e retornou lista vazia. **Instalação, abertura do APK e teste em Android não foram realizados.** O próximo passo é instalar em um aparelho compatível e validar toque físico, áudio, ciclo de vida e desempenho. O APK é debug; assinatura de produção e publicação em loja não foram realizadas.

O ZIP contém código, assets, cenas, configurações, testes, relatório e licenças. Exclui caches, SDK, templates, saves e chaves privadas. Sua integridade e conteúdo obrigatório são verificados por `tools/package_source.py`. Uma cópia extraída sem cache também passou as 158 verificações; a integração foi repetida após a inclusão final das licenças.

As instruções reutilizáveis `install_script` e `start_skill` foram salvas no rascunho das configurações do ambiente. Isso não publica nem executa o rascunho: para ativá-lo, revise e salve nas configurações do ambiente e publique o ambiente. Nenhuma publicação ou restauração em uma tarefa nova foi afirmada.
