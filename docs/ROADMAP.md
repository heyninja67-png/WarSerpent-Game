# Escopo entregue e próximos passos

## Nesta versão

A versão vertical contém uma arena offline Neon City, cinco serpentes com poderes, bots, controles simultâneos, fluxo completo de partida, economia local, coleção, loja de coins, missões, carga diária, conquistas e perfil persistente. Há sprites e interface próprios, música/efeitos, testes automatizados e configuração Android para APK de desenvolvimento.

As raridades usadas são Comum, Incomum, Rara, Épica e Lendária. Gems e fragments são contabilizados, mas não possuem lojas próprias. O registro do menu é local; adversários são bots. O seletor oferece três dificuldades do mesmo modo arena.

## Validação prioritária em Android

1. Instalar em aparelhos ARMv7/ARM64 compatíveis e verificar inicialização, renderização GLES3, margens da tela, toque simultâneo, interrupções e retorno do segundo plano.
2. Medir frame time, memória, CPU/GPU, temperatura e bateria nos perfis Baixo/Médio/Alto. Não há medição de desempenho Android nesta entrega.
3. Ajustar hitboxes, velocidade, densidade de energia, agressividade dos bots, acessibilidade e duração de partidas com sessões de jogadores.
4. Verificar atualização preservando saves, armazenamento sem espaço, restauração e mudanças de versão em dispositivos reais.

## Expansão de produto

- Extrair habilidades para módulos orientados por dados; substituir limites fixos de cinco skins. Só então ampliar gradualmente para 20 e 50+ identidades, com arte e poderes testados individualmente.
- Acrescentar raridades Mítica e Divina com itens efetivamente implementados, animações de desbloqueio e balanceamento.
- Desenvolver Cosmic Devourer, Golden Emperor, Neon Samurai, Void Dragon, Divine Serpent e as demais ideias do catálogo solicitado; não estão disponíveis atualmente.
- Adicionar Digital Void, Cosmic Rift, Toxic Wasteland, Cyber Temple e Frozen Nexus com carregamento e regras de arena configuráveis.
- Projetar utilidade e balanceamento próprios para gems/fragments, mais missões, cosméticos e progressão; manter compras sem dinheiro real enquanto esse for o escopo aprovado.
- Adicionar localização completa, opções de acessibilidade e alternativas de controle/posicionamento para jogadores canhotos.

## Engenharia e distribuição

- Medir draw calls e empacotar sprites em atlas quando os números justificarem; ampliar pooling e reutilização de buffers nos pontos identificados pelo profiler.
- Testar automatização de APK em emulador e CI, incluindo instalação, logs Android e capturas reproduzíveis.
- Preparar assinatura privada de release, AAB, revisão de políticas e materiais de loja. O APK debug atual não representa uma publicação na Play Store.
- Projetar servidor autoritativo, protocolo, autenticação, sincronização e segurança antes de adicionar multiplayer ou ranking online. Nada disso é simulado por telas nesta versão.

Cada recurso adicional deve manter o fluxo já testado e adicionar validações que demonstrem seu comportamento. O [BUILD_REPORT.md](../BUILD_REPORT.md) é a referência para o que foi efetivamente compilado e testado nesta entrega.
