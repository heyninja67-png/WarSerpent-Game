# War Serpent.io 1.2.0 — Emnio Games

Application ID: `com.emnioggs.warserpent`. Versão1.2.0, version code3. APK Android nativo realmente compilado com Godot4.6.3 em modo release otimizado e assinado com a mesma identidade das versões anteriores.

## Resultado visual e funcional

A interface foi reconstruída a partir da organização das referências fornecidas, usando arte própria. A entrega final usa o lobby de jogo com START dourado; a proposta anterior de interface plana não foi publicada como versão1.2.

- **Lobby:** perfil/moedas/gemas no topo, navegação lateral, cobra grande em pose vertical sobre plataforma animada, coleção funcional à direita, modo acima do START dourado inferior direito e barra inferior de coleção.
- **Partida:** minimapa circular real à esquerda, TIME central, SCORE compacto, classificação com até dez competidores reais, poderes circulares agrupados abaixo, joystick e aceleração por toque.
- **Gráficos:** piso de blocos roxos com profundidade e oito conjuntos de cabeça/corpo/cauda redesenhados, arredondados, brilhantes e expressivos.
- **Marcas:** novo logo original War Serpent.io e ícone Android; nova marca completa **Emnio Games** na abertura, sem frases de carregamento ou imagem padrão Godot.
- **Jogabilidade:** direção mais ágil para cobras pequenas, deadzone radial com histerese, controles liberados corretamente ao pausar/perder foco, proteção inicial e duração dos poderes visíveis, feedback de coleta e aviso de borda.
- **Mantido:** dez segmentos iniciais, oito poderes reais, bots, crescimento, colisões, loja/economia, missões, música/efeitos, inglês, save e multiplayer direto.

Capturas reais do framebuffer: [docs/screenshots](docs/screenshots). Lobby, splash, coleção, gameplay e resultados foram executados e inspecionados. As imagens não são montagens de uma interface fictícia.

## Multiplayer e minimapa

O minimapa usa as posições reais dos atores e a câmera, com atualização limitada a cada0,15s; os cantos da arena, marcador do jogador, adversários e direção do movimento são verificados. Dois controles de BOOST são áreas reais de aceleração, não poderes inventados. A habilidade equipada possui cooldown/duração reais.

A conexão direta continua com host autoritativo, até quatro humanos, IP/porta do host na tela e erros reais de timeout/desconexão. Não há servidor público, matchmaking automático, ranking online ou backend de contas. O usuário escolheu conexão direta. Veja [docs/ONLINE.md](docs/ONLINE.md).

## Testes executados

Comando: `./tools/test.sh`, saída0. Log: [docs/test-results.txt](docs/test-results.txt).

| Suíte | Verificações aprovadas |
|---|---:|
| Perfil, compras, inventário e migração |79|
| Movimento, controles, oito poderes, colisões, HUD e minimapa |72|
| Fluxo real de interface/gameplay |169|
| Dois processos OS com UDP real |25|
| **Total** |**345**|

Zero falhas no conjunto final. A integração cobre novo lobby, START, oito ações da coleção, boot Emnio Games, animações, toque/hover, cooldowns, compra/equipamento, pausa, três toques independentes, derrota ELIMINATED, reinício, persistência e proporções1280×720/1600×720/1280×900. O minimapa foi verificado contra IDs/coordenadas reais e limite de atualização. Controles online testam também direção pequena já filtrada, sem segunda deadzone.

Os testes encontraram e confirmaram correções de metadata de tween no primeiro toque e de recorte de3px na barra inferior. A captura final não apresentou erros de script ou vazamentos; houve apenas aviso de V-Sync não suportado pelo driver virtual.

Além das345 verificações, passaram **146 verificações sobre o conteúdo extraído do APK real**. Elas incluem comparação exata dos pixels importados das marcas, ícone, piso e24sprites; módulos compilados, fontes, áudio e configurações. Detalhes em [docs/android_v1_2_validation.md](docs/android_v1_2_validation.md).

## Desempenho: limites e comparação

Os corpos e energia continuam instanciados em lotes. O minimapa é atualizado aproximadamente6,7vezes/s. A prévia do lobby usa um MultiMesh e duas extremidades; efeitos da plataforma/fundo são limitados a24Hz. Auto no Android mantém o orçamento Low: alvo30FPS de renderização,5bots/420energias, física60Hz.

Comparação Linux controlada com dez cobras de quarenta segmentos e mil energias, contra a versão1.1:

| Medida | v1.1 | v1.2 |
|---|---:|---:|
| Passo físico da arena |465,58µs|449,82µs|
| Movimento/corpo individual |20,62µs|22,11µs|
| Preparação CPU do desenho |799,01µs|1037,22µs|
| Draw calls no quadro amostrado |81|104|

O novo HUD solicitado acrescentou aproximadamente0,24ms de CPU de desenho neste servidor. **Não foi descrito como mais rápido que a UI anterior.** A simulação comparável permaneceu próxima ou melhor, e o desenho em lotes evita retornar ao custo antigo de centenas de sprites individuais. Medições e dados brutos: [docs/GAMEPLAY_V1_2.md](docs/GAMEPLAY_V1_2.md).

Esses números não representam FPS Android. Não foram medidos GPU, memória, temperatura, bateria ou latência em celular. A qualidade visual maior tem custo; medições no aparelho continuam necessárias.

## APK gerado e verificado

- Android7/API24+, ARM64/ARMv7, OpenGL ES3; target API36.
- `com.emnioggs.warserpent`, versão1.2.0/code3, landscape, full-screen/edge-to-edge.
- Template release oficial verificado; manifesto não debuggable.
- Mesma assinatura RSA das versões1.0/1.1; schemas de save continuam migráveis/preservados.
- Permissão `INTERNET` para multiplayer; sem câmera, microfone ou armazenamento externo.
- APK Signature Scheme v2/v3, CRCs, código executável, recursos e alinhamento16KB verificados.
- Bibliotecas nativas idênticas ao template release oficial; correção estreita e reproduzível das authorities AndroidX seguida de nova assinatura.
- Músicas menu/arena em loop,45,18s cada, com decodificação finita/não silenciosa; áudio não foi ouvido em dispositivo físico.

Artefato local: `builds/WarSerpentIO-debug.apk` — o nome histórico não altera o modo release. Download publicado: `WarSerpentIO-v1.2.0.apk`. Tamanho/hash exatos: [docs/apk_validation.txt](docs/apk_validation.txt). Instruções: [README.md](README.md).

```sh
./tools/setup_android.sh
./tools/build_android.sh
python3 tools/validate_android.py
python3 tools/package_source.py
```

O build confere o certificado original e recusa atualizações com identidade diferente. Exporta em diretório temporário e só substitui o APK entregue depois das verificações. Java/keytool e SDK existentes foram reutilizados; nenhum SDK foi reinstalado. Gradle/javac/NDK não são necessários para templates diretos.

## Limitações e instalação

`adb devices -l` não apresentou dispositivo e não há emulador disponível. **O APK não foi instalado nem executado em Android nesta sessão.** Metadados e assinatura permitem atualizar as versões anteriores, mas a instalação `adb install -r` e retenção real de dados no celular não foram executadas.

Instale por cima da versão anterior, sem desinstalar primeiro. O logo visual padrão Godot foi desativado; Android12+ ainda pode exibir brevemente sua própria splash com o ícone do aplicativo. Toque físico, recortes de tela de cada fabricante, Wi-Fi/WAN e desempenho precisam de validação em aparelhos.

## Código, arte e licenças

O ZIP contém código, cenas, dados, testes, geradores e documentação, incluindo74PNG,2OGG e14WAV. Exclui caches, SDK/templates, saves e chaves privadas. Logo War Serpent.io, ícone e marca Emnio Games foram gerados originalmente para este projeto; sprites, piso e materiais são autoria procedural original. Não foram incorporados arquivos das imagens de referência.

Código/documentação MIT; arte/áudio conforme [assets/LICENSE.md](assets/LICENSE.md); licenças DejaVu e Godot preservadas e acessíveis nos créditos. O ZIP é verificado por CRC e conteúdo obrigatório, e uma cópia extraída é importada/testada antes da entrega.

A cópia extraída do ZIP, sem cache, passou novos imports e169 verificações de fluxo com saída0. Evidência em `docs/source-archive-validation.txt`.
