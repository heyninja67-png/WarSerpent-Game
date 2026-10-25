# War Serpent.io 1.1.0 — relatório da atualização

Estúdio: Emnio. Application ID: `com.emnioggs.warserpent`. Versão 1.1.0, version code 2.

## Entrega

APK Android nativo realmente exportado em **modo release otimizado**, assinado com a **mesma identidade de desenvolvimento da versão 1.0.0**. O nome local `builds/WarSerpentIO-debug.apk` é mantido por compatibilidade das ferramentas; não indica o modo interno da exportação. A release pública usa `WarSerpentIO-v1.1.0.apk`.

Instale por cima da versão anterior para preservar os dados; não desinstale primeiro. Assinatura e migração dos saves foram verificadas separadamente. A instalação de atualização em um aparelho não foi testada, pois não há dispositivo conectado.

- APK e fontes: pasta `builds/` e GitHub Releases.
- Assinatura, hash, tamanho, manifesto e payload exatos: [docs/apk_validation.txt](docs/apk_validation.txt).
- Instruções: [README.md](README.md).
- Engine: Godot 4.6.3 oficial, GL Compatibility, Android API24+, ARM64/ARMv7, target API36.
- Servidor público: nenhum. O usuário escolheu conexão direta.

## Mudanças solicitadas e implementadas

| Pedido | Resultado |
|---|---|
| Reduzir travamentos | Corpo com histórico circular, spatial hashing sem dicionário por segmento, consultas locais de IA, MultiMesh para comida/corpos, cache de HUD/ranking/sons, orçamento Auto conservador no Android e engine em modo release |
| Cobra inicial pequena | 10 segmentos iniciais e massa36, comparados a33 segmentos na v1.0; crescimento e boost continuam reais |
| Música e mais efeitos | Duas composições synthwave originais de45,18s, menu/arena, loop contínuo;14 WAVs no total, controles de música e efeitos independentes |
| Interface em inglês | Menu, coleção, loja, habilidades, missões, conquistas, ajustes, resultados e HUD em inglês; nomes escolhidos pelo jogador são preservados |
| Mensagem de morte | Derrota normal agora mostra **ELIMINATED**, sem alegar perda de conexão |
| UI mais bonita/animada | Menu reorganizado, materiais de botões/painéis novos, hover/toque, logo flutuante, prévia animada, transições e coleção paginada |
| Mais cobras | Solar Wyrm, Neon Samurai e Toxic Fang, com arte distinta e poderes reais; oito skins ao todo |
| Tela até as bordas | Canvas expandido, fundo cobrindo viewport, conteúdo seguro centralizado, imersão e edge-to-edge Android habilitados |
| Abertura melhor | Marca EMNIO redesenhada, símbolo/wordmark animados e transição curta; sem frases, slogans ou contadores de carregamento |
| Remover logo Godot | Desativada a imagem padrão de boot da engine; ícones nativos personalizados verificados. A splash de sistema Android12+ não pode ser totalmente eliminada e usa a marca do app |
| Modo online | ENet real: criar sala e entrar por endereço/porta, host autoritativo, até4 jogadores humanos; sem matchmaking público fictício |
| Preservar progresso | Save versão2 migra inventário, saldo, XP, recordes, nomes e configurações da v1 |

## Otimização: comparação com carga equivalente

Baseline: código anterior, commit `750f8ca`. Comparação controlada:10 cobras com40 segmentos cada e1000 energias; testes Linux no mesmo servidor. A redução da densidade padrão não foi usada para inflar essa comparação.

| Medição | Antes | Depois | Redução aproximada |
|---|---:|---:|---:|
| Movimento/corpo40segmentos |43,88µs|20,19µs|54%|
| Reconstrução do grid de corpos |217,27µs|120,40µs|45%|
| Decisão da IA |94,05µs|15,67µs|83%|
| Passo da arena |1079,80µs|494,89µs|54%|
| Preparação CPU de comandos de desenho |3,745ms|0,732ms|80%|

Detalhes, método e limites: [docs/PERFORMANCE_V1_1.md](docs/PERFORMANCE_V1_1.md). Esses números **não são FPS em Android**. O desenho foi exercitado com Xvfb/Mesa llvmpipe; não há medição de GPU, memória, temperatura ou bateria em celular.

Auto no Android escolhe o orçamento Low/30FPS alvo:5bots e420energias. Medium usa7/650; High9/1000. Física permanece60Hz para resposta e movimento suaves. A meta de30/60FPS não é uma garantia de desempenho de aparelhos. A comida mantém brilho com um único sprite em batch; corpos também são instanciados em lotes.

## Testes executados

Comando: `./tools/test.sh`. Saída completa: [docs/test-results.txt](docs/test-results.txt).

| Suíte | Verificações | Resultado |
|---|---:|---|
| Perfil/economia/migração |79|Aprovadas, zero falhas|
| Movimento/crescimento/8poderes/IA/colisões |46|Aprovadas, zero falhas|
| Fluxo real de UI/gameplay/controles |119|Aprovadas, zero falhas|
| Rede, dois processos OS/UDP real |24|Aprovadas, zero falhas|
| **Total** |**268**|**Zero falhas**|

A integração verifica oito skins/paginação/filtros/compras, áudio independente, boot sem frases, inglês, créditos, host/join reais, toque simultâneo pelo dispatcher, pausa, derrota, reinício, save e layouts1280×720/1600×720/1280×900. Ela detectou e confirmou correções de pausa duplicada por mouse emulado e callback de notificação após troca de tela.

Os testes de rede usam um cliente com a cena real `Main.tscn` e um host em processo separado, validando caminhos RPC compatíveis com o app/servidor headless. Verificam atribuição, movimento, comida, crescimento, habilidade/cooldown, encerramento do host e timeout. Snapshots comprimidos são fragmentados em blocos de950bytes, com interpolação no cliente e deltas de comida. Log: [docs/network-validation.txt](docs/network-validation.txt).

Quatro capturas reais do framebuffer atualizadas em [docs/screenshots](docs/screenshots). Nenhum erro de script ou vazamento na captura final; há apenas aviso de V-Sync não suportado pelo driver virtual. Áudio foi decodificado e analisado sem clipping/NaN/Inf; não houve avaliação auditiva em aparelho.

## Compilação e verificação Android

```sh
./tools/setup_android.sh
./tools/build_android.sh
python3 tools/validate_android.py
python3 tools/package_source.py
```

O helper usa o template **release** oficial, com checksum verificado, e a chave local original fora do projeto. Depois corrige o defeito conhecido de authorities duplicadas do AndroidX no exportador Godot4.6.3, realinha, assina e verifica o APK. O certificado deve coincidir com a v1.0; o build é recusado se a identidade mudar ou se o APK for debuggable.

Além das268 verificações de lógica/fluxo/rede, passaram58 verificações sobre recursos extraídos do APK real. Verificações independentes: assinatura v2/v3, package/versão, launcher, orientação, INTERNET como permissão necessária ao multiplayer, providers distintos, CRC, código compilado, catálogo/8skins, duas músicas, fontes/licenças, configuração de boot/fullscreen, bibliotecas release e alinhamento16KB ARM64. Detalhes: [apk_validation.txt](docs/apk_validation.txt) e [toolchain notes](docs/toolchain_notes.md).

Sem Gradle/javac/NDK: exportação com template pré-compilado. Java/keytool existentes, Build Tools35.0.1, Platform Tools37.0.1; template target36. Não foram substituídas ferramentas globais e verificação TLS/checksums permaneceu ativa.

## Limitações restantes

- `adb devices -l` retornou vazio; `/dev/kvm` não está disponível. APK não foi instalado nem executado em Android nesta máquina.
- Wi-Fi real, touchscreen físico, atualização sobre a instalação anterior e WAN/NAT não foram testados. Conexões diretas pela internet dependem de host e porta UDP acessíveis.
- Não há servidor público, matchmaking automático, conta, relay, ranking online ou economia autoritativa persistente. Salas confiam no host; se ele sai ou termina a partida, a sala fecha. [docs/ONLINE.md](docs/ONLINE.md).
- Não é uma publicação Play Store. O modo da engine é release, mas o certificado continua sendo o de desenvolvimento para permitir atualizar a instalação anterior.
- Permanecem oito skins, uma arena e progressão local. Gems/fragments ainda não possuem mercado próprio; skins/arenas adicionais continuam no roadmap.
- Medições Android reais e ajustes adicionais para o aparelho que apresentou travamentos continuam necessários; a melhoria de CPU medida não elimina todos os possíveis gargalos de GPU/driver.

## Fontes e licenças

ZIP completo com código, dados,59PNG,2OGG,14WAV, cenas, testes, relatórios e helpers. Cache, SDK, templates, saves pessoais e chaves privadas são excluídos. Código MIT; arte/áudio autorais CC0 conforme [assets/LICENSE.md](assets/LICENSE.md); fontes DejaVu e Godot preservam seus avisos próprios.

O ZIP foi extraído em um diretório temporário sem caches; imports novos e as119 verificações de fluxo passaram na cópia extraída. Evidência em `docs/source-archive-validation.txt`.
