# Core Defense — versão x86 (Assembly, DOS)

Tower defense dentro do computador, escrito em Assembly x86 de 16 bits (modo real, DOS), montado com NASM.
São seis fases, cada uma dentro de uma peça (Teclado, RAM, HD, SSD, GPU, CPU), com as mesmas regras da versão web.

## Arquivos

O código está dividido em quatro partes, uma por pessoa do grupo. O `main.asm` monta tudo junto.

| Arquivo | Dono | O que tem | Linhas |
| --- | --- | --- | --- |
| `main.asm` | Pessoa 2 | Motor e fluxo: loop, estados, teclado, som, pontos, ondas; inclui os outros arquivos | 1240 |
| `defs.inc` | Pessoa 2 | Constantes e contratos comuns: structs, estados, bits das regras, macros de desenho | 185 |
| `graficos.asm` | Pessoa 1 | Vídeo, primitivas de desenho, sprites, texto, mapas e todas as telas | 2338 |
| `inimigos.asm` | Pessoa 3 | Rotas, inimigos, ondas, pipeline da CPU e os 6 chefes | 838 |
| `torres_mapas.asm` | Pessoa 4 | Torres, combate, tiro do núcleo, habilidades e elementos do mapa | 942 |
| `data.inc` | gerado | Paleta, sprites, fonte, mapas, rotas, ondas e o registro de cada fase e chefe | — |
| `gen_data.py` + `gamedata.json` | Pessoas 1 e 3 | Gerador do `data.inc` | — |
| `CORE.COM` | — | O jogo pronto para rodar no DOS (43 KB) | — |
| `JOGAR.bat` / `dosbox-core.conf` | — | Atalho do Windows e configuração do DOSBox | — |

## Como jogar

O `CORE.COM` é um programa DOS de 16 bits. O Windows de 64 bits não roda esse tipo de programa com duplo clique (aparece "Este aplicativo não pode ser executado em seu PC"), então ele precisa de um emulador.

**No Windows:** dê duplo clique em `JOGAR.bat`. Ele procura o DOSBox-X ou o DOSBox no PC e abre o jogo. Se não achar, oferece instalar o DOSBox-X pelo `winget`. Depois de instalar, rode o `JOGAR.bat` de novo.

**Manual:** instale o DOSBox-X (dosbox-x.com) ou o DOSBox (dosbox.com) e, dentro da pasta do jogo, rode `dosbox-x -conf dosbox-core.conf`.
Sem o arquivo de configuração: abra o DOSBox, digite `mount c C:\caminho\da\pasta`, depois `c:` e `CORE`. Nesse caso aperte **Ctrl+F12** algumas vezes para dar mais velocidade ao emulador; sem isso o jogo fica lento.

**Sem instalar nada:** a página "Core Defense x86" roda este mesmo `CORE.COM` num DOSBox dentro do navegador (js-dos).

## Controles

| Tecla | Preparação | Onda |
| --- | --- | --- |
| WASD ou setas | Move o cursor | Move a mira |
| Espaço | Constrói a torre escolhida | Atira com o núcleo (também no elemento do mapa) |
| 1 a 4 | Escolhe a torre | Usa a habilidade |
| V / U | Vende / melhora a torre | — |
| R | — | Recarga rápida |
| Enter | Começa a onda (cedo = bônus) | — |
| F | Velocidade 2× | Velocidade 2× |
| P ou Esc | Pausa (Q sai para o menu) | Pausa |
| M | Som liga/desliga | Som liga/desliga |
| $ | Modo demonstração: +1000 pontos | — |
| # | Modo demonstração: a próxima onda é a do chefe | — |

As teclas `$` e `#` servem para a apresentação: `$` libera as torres das fases avançadas e `#` leva direto ao chefe, sem jogar tudo antes.

## Cada mapa joga diferente

Cada fase tem um **elemento do mapa**: uma peça do cenário que reage ao jogador. Você ativa o elemento **atirando nele com o núcleo** (mira + Espaço) durante a onda. A introdução de cada fase tem uma segunda página (Enter) que explica o elemento e o chefe.

| Fase | Elemento | O que faz | Muda a estratégia porque |
| --- | --- | --- | --- |
| Teclado | Tecla de atalho | A cada ~5 s uma tecla acende. Atire nela: DEL dá 3 de dano em volta (9 no chefe). Se ignorar 3,5 s, ela trava e a auto-repetição solta um bug | Ensina a mirar no mapa, não só nos inimigos |
| RAM | Refresh | O pente de memória carrega em 15 s. Atire nele: todos os inimigos voltam para a entrada | Os inimigos são rápidos; o refresh é o "botão de pânico" e vale guardar para a hora certa |
| HD | Busca da cabeça | O braço carrega em 10 s. Atire nele: a cabeça vai para o quadrante com mais inimigos e fica parada 8 s | As torres sob a cabeça atiram 2x; você decide onde está o bônus |
| SSD | Nivelamento | O controlador carrega em 18 s. Atire nele: cada soquete recupera 1 uso e as torres travadas destravam | Soquetes queimados voltam; vale construir e vender mais |
| GPU | Ventoinhas | As ventoinhas carregam em 11 s. Atire nelas: o calor zera e não sobe por 5 s | Permite usar Purge e Overclock sem superaquecer |
| CPU | Flush | O cache L3 carrega em 15 s. Atire nele: quem está no pipeline volta 8 casas e perde o lugar no EX | Ganha tempo quando o pipeline enche perto do núcleo |

## Chefes

Depois da última onda de cada fase vem um **alerta de chefe** e uma onda extra com escolta. Cada chefe tem mais vida e mais habilidades que o anterior; a barra de vida dele aparece no alto do mapa e o alvo do tiro do núcleo é maior (3x3 células).

| Fase | Chefe | Vida | Dano no núcleo | Habilidades |
| --- | --- | --- | --- | --- |
| Teclado | KEYLOGGER | 260 | 8 | Chama 1 bug a cada 4 s; a tecla DEL dá dano triplo nele |
| RAM | MEMORY LEAK | 165 (rápido) | 10 | Vaza 5 pontos por segundo; chama 2 vírus em outras pistas; o refresh só o empurra 1/4 |
| HD | FRAGMENTADOR | 700 | 12 | Leva metade do dano fora da cabeça de leitura e o dobro sob ela; ao morrer vira 3 worms |
| SSD | CRYPTOLOCKER | 200 | 14 | A cada 7 s trava as 2 torres mais perto e gasta o soquete delas; salta de porta em porta |
| GPU | MINERADOR | 320 | 16 | Esquenta a GPU enquanto vive; chama 2 vírus a cada 4,5 s; com meia vida fica 60% mais rápido |
| CPU | ZERO-DAY | 380 | 20 | Escudo que volta a cada 4 s; não para no EX e ignora lentidão; com meia vida chama 3 rootkits |

O dano do ZERO-DAY (20) é a vida inteira do núcleo: na última fase o chefe não pode passar.

## Como montar

```
nasm -f bin main.asm -o CORE.COM
```

Todos os `.asm`, o `defs.inc` e o `data.inc` precisam estar na mesma pasta. Para regerar os dados a partir da arte: `python3 gen_data.py`.

## Quem é dono de cada rotina

O quadro da onda (`wave_tick`, Pessoa 2) chama as partes dos outros na ordem: `wt_spawners`, `wt_pipeline`, `boss_tick` e `wt_move` (Pessoa 3), depois `el_tick` e `wt_towers` (Pessoa 4). Na lista de variáveis do `main.asm`, cada uma tem o dono entre colchetes (`[P3]`, `[P1+P2]`...).

**Pessoa 2 — Motor e fluxo (`main.asm`, `defs.inc`):** `start`, `exit_game`, `get_tick`, `in_game`, `poll_keys`, `beep`, `beep_raw`, `play_seq`, `sound_tick`, `speaker_off`, `itoa`, `hex4`, `sb_reset`, `sb_str`, `sb_num`, `sb_chr`, `toast`, `toast_sb`, `rnd`, `new_game`, `unlocked`, `gain`, `start_prep`, `start_wave`, `end_wave`, `after_wend`, `game_over`, `popcnt4`, `nthbit`, `randbit`, `wave_tick`, `tick`, `on_key`, `key_tab`, `k_none`, `k_menu`, `k_ctrl`, `k_sel`, `k_intro`, `k_boss`, `k_prep`, `k_wave`, `k_wend`, `k_end`

**Pessoa 1 — Gráficos e telas (`graficos.asm`):** `video_init`, `crtc_tab`, `set_palette`, `wait_vsync`, `blit`, `pset`, `fillrect`, `frame`, `clear_screen`, `drawspr`, `drawtext`, `textw`, `ctext`, `rtext`, `line`, `circle`, `unpack_map`, `burst`, `add_fx`, `render`, `rnd_tab`, `blinkc`, `r_menu`, `menu_opts`, `r_ctrl`, `r_sel`, `r_intro`, `draw_bg`, `slot_frame`, `draw_world`, `hd_q`, `hud_top`, `hud_bottom`, `draw_panel`, `draw_range`, `rg_dot`, `draw_toast`, `caixa`, `r_prep`, `r_wave`, `r_aviso`, `r_wend`, `r_over`, `r_win`, `r_intro2`, `r_boss`, `draw_boss_e`, `draw_bossbar`, `box_frame`, `draw_el`, `draw_fans`, `draw_pause`

**Pessoa 3 — Inimigos e chefes (`inimigos.asm`):** `route_rec`, `epos`, `ecell`, `spawn`, `hit`, `kill`, `spawn_boss`, `boss_armor`, `boss_killed`, `boss_reached`, `bt_every`, `boss_tick`, `boss_lock`, `boss_jump`, `wt_spawners`, `wt_pipeline`, `wt_move`

**Pessoa 4 — Torres, combate e mapas (`torres_mapas.asm`):** `quad_of`, `heat_add`, `in_box`, `el_tick`, `el_use`, `el_fn`, `el_none`, `el_ram`, `el_hd`, `el_ssd`, `el_gpu`, `el_cpu`, `wt_towers`, `tower_fire`, `tf_apply`, `cursor_slot`, `act_build`, `no_money`, `act_sell`, `act_upgrade`, `core_shoot`, `use_ab`

## Como funciona por dentro

**Vídeo.** O jogo liga o modo VGA 13h (`int 10h`) e reprograma o CRTC por portas de E/S (`out 3D4h`/`3C2h`) para um timing de 480 linhas com cada linha repetida 4 vezes. O resultado é uma tela de 320×120 com memória linear em `A000:0000`.
O jogo desenha num back buffer de 160×120 em outro segmento, e o `blit` copia cada pixel duas vezes na horizontal. A tela fica com a mesma resolução lógica do projeto (160×120), ocupando o monitor inteiro.

**Memória.** É um programa `.COM`, então código, dados e pilha ficam num único segmento de 64 KB (`org 100h`). O back buffer e o mapa descompactado ficam no segmento seguinte (`CS + 1000h`), acessado por `ES`. É segmentação real do x86: `DS` aponta para os dados do jogo e `ES` para o buffer de vídeo.

**Mapas.** Cada mapa é uma grade de 20×13 tiles de 8×8. Os 336 tiles diferentes das seis fases ficam guardados uma vez só, com 4 bits por pixel. Os seis mapas ocupam 14 KB em vez de 100 KB, e são descompactados quando a fase começa.

**Tempo, teclado e som.**
- O ritmo vem do contador da BIOS em `0040:006C`, que conta 18,2 ticks por segundo.
- O teclado é lido pela `int 16h`, as setas inclusive.
- O som sai pelo alto-falante do PC: canal 2 do PIT, portas `42h`/`43h`/`61h`.

**Chefes e elementos.** Cada fase tem um registro EXT (`ext_tab` em `data.inc`) com a caixa do elemento em tiles, o tempo de carga, os textos e todos os números do chefe. O chefe é o tipo de inimigo 6; as habilidades são bits de `X_BFL` e períodos testados com `div` (`bt_every`), e a ação de cada elemento sai de uma tabela de salto (`call [el_fn+bx]`).

**Dados.** Inimigos e torres são vetores de structs de tamanho fixo: 16 bytes por inimigo, 8 por torre. As fases são registros com campos em deslocamentos fixos (`[si+P_FLAGS]`). As regras de cada componente são bits de uma máscara testados com `test`.

### Conceitos de AOC que aparecem no código

| Conceito | Onde |
| --- | --- |
| CISC: instruções de string | `rep stosb`/`stosw` no preenchimento, `rep movsw` na cópia do mapa, `lodsb`/`lodsw` na leitura de sprites e tiles |
| Instruções especializadas | `xlat` (troca de cores), `loop`, `pusha`/`popa`, `setc`, `bt`, `imul` com 3 operandos, `movzx`/`movsx` |
| Segmentação | `DS` = dados, `ES` = back buffer, `A000h` = VGA, `0040h` = área da BIOS |
| E/S mapeada em portas | `in`/`out` no CRTC, na paleta (`3C8h`/`3C9h`), no retraço vertical (`3DAh`) e no PIT |
| Interrupções de software | `int 10h` (vídeo), `int 16h` (teclado), `int 21h` (DOS) |
| Modos de endereçamento | Base + índice + deslocamento (`[bp+di+P_TOWT]`), registrador indireto, imediato |
| Tabelas de salto | Estados do jogo: `jmp [key_tab+bx]` e `call [rnd_tab+bx]` |
| Pipeline (fase CPU) | 5 estágios, parada no EX e bolha causada pelo Vírus |

## Diferenças em relação à versão web

- A lógica roda a 18,2 quadros por segundo (relógio da BIOS) em vez de 20.
- Não tem mouse; tudo é pelo teclado.
- O menu tem a opção SAIR, que volta ao DOS.
- Fases vencidas ficam marcadas com OK até fechar o jogo; não há salvamento em disco.
- As durações estão em quadros: como o x86 roda a 18,2 quadros/s, cargas e habilidades duram cerca de 10% a mais que na web.
