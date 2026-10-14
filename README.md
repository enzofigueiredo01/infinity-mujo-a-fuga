# Infinity Mujo — A Fuga

Protótipo de plataforma 2D de precisão (estilo Celeste) feito em **Godot 4.7** pela **Mujo Estudio**.

Versão invertida do *Infinity Mujo*: você é o **bilionário** que aceitou a proposta do mágico
(riqueza infinita e vida eterna) e agora precisa fugir, para sempre, de um **caramujo imortal
e superinteligente**. Se ele te tocar, você perde tudo.

## Como jogar

1. Abra o Godot 4.7 → **Importar** → selecione `project.godot`.
2. Aperte **F5**.

| Tecla | Ação |
|---|---|
| A / D ou setas | correr |
| ESPAÇO | pular (no ar: pulo duplo, a partir da fase 3) |
| segurar ESPAÇO caindo | planar (fase 4) |
| SHIFT | dash (fase 2) |
| ESC | pausar |
| R | recomeçar a fase |

## Regras

- O homem é imortal: espinhos, lasers, carros e trens só o empurram.
- **Só o toque do caramujo acaba com ele.** A fase recomeça.
- O caramujo rasteja por chão, paredes e tetos, salta no casco entre plataformas e cai do teto.
- Ele fica mais rápido quanto mais você demora e, quando chega perto, brilha e dá uma **investida de muco**.

## Fases

| # | Cenário | Nova habilidade | Saída |
|---|---|---|---|
| 1 | Cidade | correr e pular | helicóptero |
| 2 | Metrô da meia-noite | dash (tênis turbo de ouro) | saída de emergência |
| 3 | Bunker moderno | pulo duplo (jetpack de bolso) | elevador |
| 4 | Cidade tecnológica | planar (guarda-chuva) | carro voador |
| 5 | Estação espacial | gravidade baixa | cápsula de fuga |

Os mapas ficam em texto em `scripts/level_data.gd` (legenda no topo do arquivo).

## Trilha sonora

Uma faixa calma (inspirada em Celeste) para o menu e para cada fase, em loop, em `assets/music/`:

| Faixa | Clima |
|---|---|
| Menu — Proposta | piano solo |
| Fase 1 — Primeiros Passos | piano em arpejos, Lá menor |
| Fase 2 — Meia-Noite | Rhodes lo-fi e sinos, Ré menor |
| Fase 3 — Concreto | pulso contido, Mi menor |
| Fase 4 — Neon | synthwave tranquilo, Fá lídio |
| Fase 5 — Gravidade Zero | ambiente flutuante, Mi♭ maior |

As faixas são geradas pelo script `tools/compor_trilha.py` (Python + numpy):
`python3 tools/compor_trilha.py saida_wav` e depois converta para `.ogg`.

## Estrutura

- `scenes/` — logo de introdução, tela inicial e cena do jogo
- `scripts/` — jogador, caramujo (`snail.gd` + navegação `snail_nav.gd`), mapa, obstáculos, HUD
- `assets/` — artes, fonte, vídeo de fundo, trilha sonora e efeitos sonoros
- `tools/` — script que compõe a trilha sonora
