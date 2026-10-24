# Validação da jogabilidade

Motor: Godot 4.6.3 stable. Os comandos abaixo foram executados no ambiente Linux de desenvolvimento. Esta validação não mede o desempenho de uma GPU ou de um aparelho Android.

## Testes automatizados

Comando, na raiz do projeto:

```sh
godot --headless --path . --script tests/test_gameplay.gd
```

Resultado: **34 verificações passaram; zero falhas**, sem avisos de recursos retidos na execução final.

Cobertura:

- Movimento contínuo, distância percorrida, independência do tempo a 30/60 passos por segundo e curvas com espaçamento corporal de 10 pixels.
- Coleta real na arena, crescimento, pontuação, aceleração com consumo de massa e limite mínimo.
- As cinco habilidades: velocidade elétrica, redução de movimento pelo fogo, trilha congelada, consumo de escudo e evasão espectral com duração limitada.
- Cooldowns, duração, reutilização e resistência espectral à lentidão.
- Spatial hashing em limites de células e coordenadas negativas.
- Três toques simultâneos com identidades independentes: direção, boost e habilidade; soltar o joystick preserva o boost pressionado.
- IA evitando a borda, colisão cabeça-corpo, atribuição de eliminação, início da derrota e emissão das estatísticas reais.

O teste usa instâncias do modelo e da própria arena. Não substitui testes manuais em tela sensível ao toque.

## Simulação com IA

```sh
godot --headless --path . --script tests/simulate_arena.gd
```

Execução registrada: **6.571 passos de física**, **6,336 segundos de tempo real no servidor**, média de **0,964 ms por passo**; zero falhas. A simulação é determinística por seed, usa IA piloto e nove bots com as regras normais. Partidas terminam ao morrer ou ao completar 30 segundos de tempo simulado.

| Cobra | Tempo simulado | Pontuação | Estado ao terminar |
|---|---:|---:|---|
| Volt Serpent | 4,52 s | 50 | Derrotada |
| Inferno Viper | 30,00 s | 211 | Viva |
| Frost Fang | 21,03 s | 166 | Derrotada |
| Cyber Reaper | 30,00 s | 154 | Viva |
| Shadow Phantom | 20,67 s | 183 | Derrotada |

Os tempos são uma referência da execução headless Linux, sem custo de renderização. **Não demonstram 30/60 FPS em Android**, consumo de bateria ou latência real de toque.

## Perfis gráficos

- **Baixo:** sete bots, 720 partículas de energia iniciais, partículas visuais reduzidas e sem halos extras de coleta/boost.
- **Médio:** nove bots, 1.000 partículas de energia iniciais e halos básicos.
- **Alto:** mesma simulação do Médio, com aura visual adicional durante boost e habilidades.
- **Auto:** escolhe Baixo se `OS.get_processor_count() < 4`, senão Médio. É uma heurística simples de CPU, não uma avaliação da GPU nem uma promessa de desempenho.

Os modos mantêm as mesmas regras, velocidades, hitboxes e dificuldades de IA. O perfil Baixo reduz a população simulada para conter o custo de CPU. A energia é reutilizada em um pool limitado a 1.500 entradas; efeitos visuais são limitados a 240 partículas; renderização descarta objetos fora da câmera; colisões e coleta usam spatial hashing; decisões dos bots são distribuídas em intervalos.
