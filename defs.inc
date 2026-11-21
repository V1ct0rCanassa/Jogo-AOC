; =====================================================================
; defs.inc  ·  CONSTANTES E CONTRATOS COMUNS (dono: Pessoa 2)
;
;   Structs (inimigo 16 bytes, torre 8 bytes), registro da fase e do chefe,
;   estados, bits das regras e as macros de desenho da Pessoa 1.
;   Mudou algo aqui? Avise os outros três antes de subir.
; =====================================================================

; =====================================================================
;  CORE DEFENSE  -  versão x86 (DOS, modo real 16 bits, NASM)
;  Montar:  nasm -f bin main.asm -o CORE.COM   (main.asm inclui os outros)
;  Rodar:   DOSBox (cycles=max)  ->  CORE
;
;  Vídeo: VGA modo 13h reprogramado para 320x120 (timing de 480 linhas,
;  cada linha repetida 4x). O jogo desenha num back buffer 160x120 e o
;  blit duplica cada pixel na horizontal. Lógica a 18,2 quadros/s (tick
;  da BIOS), teclado pela int 16h, som pelo alto-falante (PIT canal 2).
; =====================================================================
bits 16

W       equ 160
H       equ 120
MAXE    equ 64              ; Quantidade de inimigos
ESZ     equ 16              ; bytes por inimigo
MAXT    equ 10              ; soquetes (torres)
TSZ     equ 8
MAXFX   equ 24
FXSZ    equ 8
MAXP    equ 48
PSZ     equ 8
BGOFF   equ 5000h           ; mapa descompactado no segmento do back buffer
PREPT   equ 364             ; 20 s de preparação
ABT     equ 100             ; duração das habilidades (ticks)

; ---- struct inimigo ----
E_ACT   equ 0
E_TYPE  equ 1               ; 0 bug 1 virus 2 trojan 3 worm 4 ransom 5 rootkit 6 Chefes
E_ROUTE equ 2
E_FLAGS equ 3               ; byte: 1 = escudo, 2 = já passou pelo EX, 4 = já travou torre, 8 = segurado por outro
E_D     equ 4               ; distância na rota (1/16 px)
E_HP    equ 6
E_MAX   equ 8
E_SPD   equ 10              ; Vai somar em E_D
E_SLOW  equ 11              ; Lentidao, velocidade pela metade
E_STOP  equ 12              
E_FLASH equ 13              ; vira 2 (levou dano) ou 3 (o escudo absorveu)
E_X     equ 14
E_Y     equ 15
; ---- struct torre (por soquete) ----
T_TYPE  equ 0               ; 0 vazio, 1..4
T_LVL   equ 1
T_CD    equ 2               ; recarga em 1/4 de tick
T_LOCK  equ 3
T_INV   equ 4               ; word: pontos investidos
T_FLASH equ 6
T_USE   equ 7               ; desgaste (SSD)
; ---- registro de fase (gerado em data.inc) ----
P_NAME  equ 0
P_TITLE equ 2
P_INTRO equ 4
P_REGRA equ 10
P_BAND  equ 16
P_FLAGS equ 17
P_COREX equ 18
P_COREY equ 19
P_CSPR  equ 20
P_ICON  equ 22
P_NSLOT equ 24
P_NROUT equ 25
P_SLOTS equ 26
P_ROUTS equ 28
P_INIT  equ 30
P_OPENW equ 31
P_OPENM equ 32
P_OMSG  equ 34
P_START equ 36
P_CAP   equ 38
P_NTOW  equ 40
P_ABIL  equ 41
P_TOWT  equ 42
P_TOWN  equ 46
P_NWAV  equ 54
P_WORM  equ 55
P_WAVES equ 56
P_ESPD  equ 58
P_EDMG  equ 64
P_EPTS  equ 70
P_HP    equ 82
P_MAP   equ 84
F_CAP   equ 1
F_HEAD  equ 2
F_WEAR  equ 4
F_RAND  equ 8
F_HEAT  equ 16
F_AREA  equ 32
F_PIPE  equ 64
; ---- estados ----
ST_MENU equ 0
ST_CTRL equ 1
ST_SEL  equ 2
ST_INTRO equ 3
ST_PREP equ 4
ST_WAVE equ 5
ST_AVISO equ 6
ST_WEND equ 7
ST_OVER equ 8
ST_WIN  equ 9
ST_BOSS equ 10              ; alerta de chefe antes da última preparação
ET_BOSS equ 6               ; tipo de inimigo do chefe
; registro EXT (elemento do mapa + chefe), um por fase, gerado em data.inc
X_ELN   equ 0               ; nome do elemento
X_TXT   equ 2               ; 3 linhas de explicação
X_BOX   equ 8               ; caixa do elemento em tiles: x0,y0,x1,y1 (255 = sem caixa)
X_BOX2  equ 12
X_CHG   equ 16              ; quadros para carregar
X_HINT  equ 18
X_BN    equ 20              ; nome do chefe
X_BD    equ 22              ; 3 linhas sobre o chefe
X_BHP   equ 28
X_BSPD  equ 30
X_BDMG  equ 31
X_BPTS  equ 32
X_EVERY equ 34              ; chama reforços a cada N quadros
X_CALL  equ 35
X_NCALL equ 36
X_DRAIN equ 37              ; tira 1 ponto a cada N quadros
X_BFL   equ 38
X_LOCK  equ 39              ; trava torres a cada N quadros
X_JUMP  equ 40              ; troca de porta a cada N quadros
X_SHLD  equ 41              ; escudo volta a cada N quadros
X_HALF  equ 42              ; tipo chamado com meia vida (255 = nenhum)
X_NHALF equ 43
X_BRT   equ 44
X_SPLIT equ 45              ; worms ao morrer
X_BWAV  equ 46              ; grupos da onda do chefe
X_BSPR  equ 48
X_BSPR2 equ 50
X_KEYS  equ 52              ; teclas do teclado (0 = elemento com caixa)
BF_ARMOR equ 1
BF_ENR   equ 2
BF_NOEX  equ 4
BF_NOSLOW equ 8
BF_HEAT  equ 16

; ---------------------------------------------------------------------
; macros de desenho (argumentos imediatos ou registradores)
%macro RECT 5            ; x,y,w,h,cor
    mov ax,%1
    mov bx,%2
    mov cx,%3
    mov dx,%4
    mov si,%5
    call fillrect
%endmacro
%macro FRAME 5
    mov ax,%1
    mov bx,%2
    mov cx,%3
    mov dx,%4
    mov si,%5
    call frame
%endmacro
%macro TEXT 5            ; str,x,y,cor,escala
    mov si,%1
    mov ax,%2
    mov bx,%3
    mov cl,%4
    mov ch,%5
    call drawtext
%endmacro
%macro CTEXT 6           ; str,y,cor,escala,x0,w
    mov si,%1
    mov bx,%2
    mov cl,%3
    mov ch,%4
    mov dx,%5
    mov di,%6
    call ctext
%endmacro
%macro SPR 3             ; sprite,x,y
    mov si,%1
    mov ax,%2
    mov bx,%3
    call drawspr
%endmacro
