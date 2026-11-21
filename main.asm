; =====================================================================
; main.asm  ·  PESSOA 2 — MOTOR E FLUXO DO JOGO
;
;   - Início/saída, loop principal, relógio da BIOS, teclado (int 16h), som (PIT)
;   - Máquina de estados: tick, on_key e as teclas de cada estado (key_tab)
;   - Economia: pontos, ganhos, desbloqueio de torres; mensagens (toast)
;   - Fluxo: new_game, preparação, onda (wave_tick chama os módulos), fim, chefe
;   - Monta o jogo inteiro: inclui os outros três arquivos, os dados e as variáveis
;
; Arquivos do jogo e donos:
;   main.asm          Pessoa 2  motor e fluxo (este arquivo; monta tudo)
;   defs.inc          Pessoa 2  constantes, structs e macros comuns
;   graficos.asm      Pessoa 1  vídeo, desenho e telas
;   inimigos.asm      Pessoa 3  inimigos, ondas e chefes
;   torres_mapas.asm  Pessoa 4  torres, combate e elementos do mapa
;   data.inc          gerado por gen_data.py (arte, fases, ondas, chefes)
;
; Parte do Core Defense x86. Montado junto pelo main.asm:
;   nasm -f bin main.asm -o CORE.COM
; =====================================================================

cpu 386
org 100h

%include "defs.inc"

section .text

; =====================================================================
start:
    cld
    mov di,bss_start                  ; zera variáveis (ES=CS aqui)
    mov cx,bss_end-bss_start
    xor al,al
    rep stosb
    mov ax,cs
    add ax,1000h
    mov [bufseg],ax
    mov es,ax                         ; ES = back buffer daqui em diante
    mov byte [spk],1
    call get_tick
    xor ax,0ACE1h
    or ax,1
    mov [seed],ax
    call video_init
    call set_palette
    mov byte [state],ST_MENU
    call get_tick
    mov [lasttick],ax
.main:
    call poll_keys
    cmp byte [quit],0
    jne exit_game
    call get_tick
    cmp ax,[lasttick]
    je .main
    mov [lasttick],ax
    call tick
    cmp byte [fast],0
    je .r
    call in_game
    jnc .r
    call tick
.r: call sound_tick
    call render
    call wait_vsync
    call blit
    jmp .main

exit_game:
    call speaker_off
    mov ax,3
    int 10h
    mov dx,s_bye
    mov ah,9
    int 21h
    mov ax,4C00h
    int 21h

get_tick:                             ; ax = contador da BIOS (18,2 Hz)
    push es
    push word 40h
    pop es
    mov ax,[es:6Ch]
    pop es
    ret

in_game:                              ; CF=1 se em preparação/onda/aviso/fim de onda/alerta
    cmp byte [state],ST_BOSS
    je .yes
    cmp byte [state],ST_PREP
    jb .no
    cmp byte [state],ST_WEND
    ja .no
.yes: stc
    ret
.no: clc
    ret

; =====================================================================
; teclado
poll_keys:
.l: mov ah,1
    int 16h
    jz .done
    xor ah,ah
    int 16h
    cmp ah,48h
    jne .n1
    mov al,'w'
    jmp .go
.n1: cmp ah,50h
    jne .n2
    mov al,'s'
    jmp .go
.n2: cmp ah,4Bh
    jne .n3
    mov al,'a'
    jmp .go
.n3: cmp ah,4Dh
    jne .n4
    mov al,'d'
    jmp .go
.n4: cmp al,'A'
    jb .go
    cmp al,'Z'
    ja .go
    or al,20h
.go: test al,al
    jz .l
    call on_key
    cmp byte [quit],0
    jne .done
    jmp .l
.done: ret

; =====================================================================
; som (alto-falante do PC)
beep:                                 ; bx = Hz, cl = ticks
    mov word [snd_seq],0
beep_raw:
    cmp byte [muted],0
    jne .x
    pusha
    mov dx,12h
    mov ax,34DCh
    div bx
    mov bx,ax
    mov al,0B6h
    out 43h,al
    mov al,bl
    out 42h,al
    mov al,bh
    out 42h,al
    in al,61h
    or al,3
    out 61h,al
    mov [snd_t],cl
    popa
.x: ret
play_seq:                             ; si = lista (dw Hz, db ticks) ... dw 0
    cmp byte [muted],0
    jne .x
    mov [snd_seq],si
    mov byte [snd_t],0
    call speaker_off
.x: ret
sound_tick:
    cmp byte [snd_t],0
    je .seq
    dec byte [snd_t]
    jnz .x
    call speaker_off
.seq: mov si,[snd_seq]
    test si,si
    jz .x
    lodsw
    test ax,ax
    jz .end
    mov bx,ax
    lodsb
    mov cl,al
    mov [snd_seq],si
    call beep_raw
    ret
.end: mov word [snd_seq],0
.x: ret
speaker_off:
    push ax
    in al,61h
    and al,0FCh
    out 61h,al
    pop ax
    ret

; ---- números e strings ----
itoa:                                 ; ax -> si = string decimal
    push ax
    push bx
    push dx
    push di
    mov di,numbuf+7
    mov byte [di],0
    mov bx,10
.l: xor dx,dx
    div bx
    add dl,'0'
    dec di
    mov [di],dl
    test ax,ax
    jnz .l
    mov si,di
    pop di
    pop dx
    pop bx
    pop ax
    ret
hex4:                                 ; ax -> si = "0XNNNN"
    push ax
    push bx
    push cx
    push di
    mov di,numbuf
    mov word [di],'0X'
    add di,2
    mov cx,4
.l: rol ax,4
    mov bl,al
    and bl,0Fh
    add bl,'0'
    cmp bl,'9'
    jbe .d
    add bl,7
.d: mov [di],bl
    inc di
    loop .l
    mov byte [di],0
    mov si,numbuf
    pop di
    pop cx
    pop bx
    pop ax
    ret
sb_reset:
    mov word [sbpos],strbuf
    mov byte [strbuf],0
    ret
sb_str:                               ; anexa si
    push ax
    push si
    push di
    mov di,[sbpos]
.l: lodsb
    mov [di],al
    test al,al
    jz .e
    inc di
    jmp .l
.e: mov [sbpos],di
    pop di
    pop si
    pop ax
    ret
sb_num:                               ; anexa ax
    push si
    call itoa
    call sb_str
    pop si
    ret
sb_chr:                               ; anexa al
    push di
    mov di,[sbpos]
    mov [di],al
    mov byte [di+1],0
    inc word [sbpos]
    pop di
    ret
toast:                                ; si=str al=cor ah=vida
    pusha
    mov [toast_c],al
    mov [toast_l],ah
    mov di,toastbuf
    mov cx,38
.l: lodsb
    mov [di],al
    test al,al
    jz .e
    inc di
    loop .l
    mov byte [di],0
.e: popa
    ret
toast_sb:                             ; toast do strbuf
    push si
    mov si,strbuf
    call toast
    pop si
    ret

rnd:                                  ; ax = LFSR de Galois 16 bits
    mov ax,[seed]
    shr ax,1
    jnc .s
    xor ax,0B400h
.s: mov [seed],ax
    ret

; =====================================================================
; jogo
new_game:                             ; al = fase 0..5
    pusha
    mov [phidx],al
    movzx bx,al
    shl bx,1
    mov si,[phase_tab+bx]
    mov [ph],si
    mov ax,[ext_tab+bx]
    mov [ext],ax
    mov di,game_start                 ; zera todo o estado da partida
.z: mov byte [di],0
    inc di
    cmp di,game_end
    jb .z
    mov word [vida],20
    mov ax,[si+P_START]
    mov [pontos],ax
    mov al,[si+P_INIT]
    mov [active],al
    mov bx,[si+P_SLOTS]
    mov al,[bx]
    mov [cursx],al
    mov al,[bx+1]
    mov [cursy],al
    mov byte [mirax],8
    mov byte [miray],7
    mov al,[si+P_TOWT]
    mov [sel],al
    mov byte [ammo],12
    mov byte [el_last],255
    call unpack_map
    popa
    ret

unlocked:                             ; al = tipo de torre -> CF=1 se liberada
    push bx
    push cx
    push si
    mov si,[ph]
    movzx cx,byte [si+P_NTOW]
    xor bx,bx
.l: cmp bx,cx
    jae .no
    cmp [si+P_TOWT+bx],al
    je .f
    inc bx
    jmp .l
.f: shl bx,1
    mov bx,[si+P_TOWN+bx]
    cmp [ganhos],bx
    jb .no
    stc
    jmp .x
.no: clc
.x: pop si
    pop cx
    pop bx
    ret

gain:                                 ; ax = pontos, cl = 1 se veio de abate
    pusha
    mov dx,[ganhos]
    mov [g_before],dx
    add [pontos],ax
    mov si,[ph]
    test byte [si+P_FLAGS],F_CAP
    jz .nc
    mov bx,[si+P_CAP]
    cmp [pontos],bx
    jbe .nc
    mov [pontos],bx
.nc: add [ganhos],ax
    test cl,cl
    jz .nk
    add [wavegain],ax
.nk: movzx cx,byte [si+P_NTOW]
    xor bx,bx
.ul: cmp bx,cx
    jae .x
    push bx
    shl bx,1
    mov dx,[si+P_TOWN+bx]
    pop bx
    test dx,dx
    jz .nx
    cmp [g_before],dx
    jae .nx
    cmp [ganhos],dx
    jb .nx
    mov al,[si+P_TOWT+bx]
    mov [newtower],al
    call sb_reset
    push si
    mov si,s_novatorre
    call sb_str
    movzx di,al
    shl di,1
    mov si,[tower_name+di]
    call sb_str
    pop si
    mov ax,3C06h
    call toast_sb
    push si
    mov si,seq_unlock
    call play_seq
    pop si
.nx: inc bx
    jmp .ul
.x: popa
    ret

start_prep:
    inc byte [wave]
    mov word [prept],PREPT
    mov byte [newtower],0
    mov byte [state],ST_PREP
    mov al,[sel]
    call unlocked
    jc .x
    mov si,[ph]
    mov al,[si+P_TOWT]
    mov [sel],al
.x: ret

start_wave:
    pusha
    mov ax,[prept]
    xor dx,dx
    mov bx,18
    div bx
    test ax,ax
    jz .ne
    mov cl,0
    call gain
    call sb_reset
    mov si,s_cedo
    call sb_str
    call sb_num
    push ax
    mov ax,1E05h
    call toast_sb
    pop ax
.ne: mov word [wavegain],0
    mov di,spawners
.z: mov byte [di],0
    inc di
    cmp di,spawners+4*8
    jb .z
    mov si,[ph]
    mov al,[wave]
    cmp al,[si+P_NWAV]
    jbe .nw
    mov si,[ext]                      ; última onda: escolta + chefe
    mov si,[si+X_BWAV]
    jmp .lst
.nw: mov bx,[si+P_WAVES]
    movzx ax,byte [wave]
    dec ax
    shl ax,1
    add bx,ax
    mov si,[bx]
.lst: mov di,spawners
.g: cmp byte [si],255
    je .done
    mov [di],si
    mov al,[si+1]
    mov [di+2],al
    mov byte [di+3],0
    mov ax,[si+7]
    mov [di+4],ax
    add si,9
    add di,8
    cmp di,spawners+4*8
    jb .g
.done: mov byte [state],ST_WAVE
    mov si,seq_wave
    call play_seq
    mov di,[ext]
    cmp byte [wave],1                 ; primeira onda: dica do elemento do mapa
    jne .nh
    mov si,[di+X_HINT]
    mov ax,5A06h
    call toast
.nh: mov si,[ph]
    mov al,[wave]
    cmp al,[si+P_NWAV]
    jbe .x
    call sb_reset                     ; onda do chefe
    mov si,s_chefe_dp
    call sb_str
    mov si,[di+X_BN]
    call sb_str
    mov ax,3C08h
    call toast_sb
    mov si,seq_boss
    call play_seq
.x: popa
    ret

end_wave:
    pusha
    movzx ax,byte [wave]
    imul ax,10
    add ax,50
    mov [bonus],ax
    mov cl,0
    call gain
    mov dword [ab],0
    mov byte [el_on],0                ; tecla acesa some no fim da onda
    mov byte [el_t],0
    mov byte [state],ST_WEND
    mov si,seq_wave
    call play_seq
    popa
    ret

after_wend:
    pusha
    mov si,[ph]
    mov al,[wave]
    mov ah,[si+P_NWAV]
    inc ah                            ; ondas normais + chefe
    cmp al,ah
    jb .more
    mov byte [state],ST_WIN
    mov cl,[phidx]
    mov al,1
    shl al,cl
    or [done],al
    mov si,seq_win
    call play_seq
    jmp .x
.more: inc al
    cmp al,[si+P_OPENW]
    jne .np
    mov al,[si+P_OPENM]
    or [active],al
    mov byte [avisot],50
    mov byte [state],ST_AVISO
    mov bx,200
    mov cl,4
    call beep
    jmp .x
.np: cmp al,ah                        ; a próxima é a do chefe: alerta antes
    jne .sp
    mov byte [state],ST_BOSS
    mov si,seq_boss
    call play_seq
    jmp .x
.sp: call start_prep
.x: popa
    ret

game_over:
    mov byte [state],ST_OVER
    push si
    mov si,seq_lose
    call play_seq
    pop si
    ret

popcnt4:                              ; al = máscara -> cl = bits ligados
    push ax
    xor cl,cl
    and al,0Fh
.l: test al,al
    jz .x
    shr al,1
    adc cl,0
    jmp .l
.x: pop ax
    ret
nthbit:                               ; al = máscara, cl = n -> bl = índice do n-ésimo bit
    push ax
    push cx
    xor bl,bl
.l: test al,1
    jz .n
    test cl,cl
    jz .x
    dec cl
.n: shr al,1
    inc bl
    cmp bl,4
    jb .l
    xor bl,bl
.x: pop cx
    pop ax
    ret
randbit:                              ; al = máscara -> bl = rota aleatória
    push ax
    push cx
    push dx
    call popcnt4
    movzx cx,cl
    push ax
    call rnd
    xor dx,dx
    div cx
    mov cl,dl
    pop ax
    call nthbit
    pop dx
    pop cx
    pop ax
    ret

; ---- quadro da onda ----
wave_tick:                            ; [P2] um quadro de onda: chama cada módulo na ordem
    mov si,[ph]
    mov al,[si+P_FLAGS]
    mov [flags],al
    call wt_spawners                  ; [P3] solta os inimigos das ondas
    call wt_pipeline                  ; [P3] fase CPU: paradas e bolhas
    call boss_tick                    ; [P3] habilidades do chefe
    call el_tick                      ; [P4] elemento do mapa
    call wt_move                      ; [P3] movimento; CF=1 = núcleo caiu
    jc .x
    call wt_towers                    ; [P4] torres, calor, munição, habilidades
    ; ---- fim da onda? ----
    mov di,spawners
.ec: cmp word [di],0
    je .ecn
    cmp byte [di+2],0
    jne .x
.ecn: add di,8
    cmp di,spawners+4*8
    jb .ec
    mov di,enemies
.ee: cmp byte [di+E_ACT],0
    jne .x
    add di,ESZ
    cmp di,enemies+MAXE*ESZ
    jb .ee
    call end_wave
.x: ret

; =====================================================================
; tick geral
tick:
    inc word [frm]
    call in_game
    jnc .x
    cmp byte [paused],0
    jne .x
    cmp byte [toast_l],0
    je .t1
    dec byte [toast_l]
.t1: cmp byte [seekh],0               ; busca: a cabeça fica parada
    je .tq
    dec byte [seekh]
    jmp .t2
.tq: inc byte [qt]
    cmp byte [qt],100
    jb .t2
    mov byte [qt],0
    inc byte [quad]
    and byte [quad],3
.t2: mov di,fxs                       ; efeitos
.fl: cmp byte [di],0
    je .fn
    dec byte [di]
.fn: add di,FXSZ
    cmp di,fxs+MAXFX*FXSZ
    jb .fl
    mov di,parts                      ; partículas
.pl: cmp byte [di],0
    je .pn
    dec byte [di]
    movsx ax,byte [di+6]
    add [di+2],ax
    movsx ax,byte [di+7]
    add [di+4],ax
.pn: add di,PSZ
    cmp di,parts+MAXP*PSZ
    jb .pl
    cmp byte [coreflash],0
    je .t3
    dec byte [coreflash]
.t3: cmp byte [shake],0
    je .t4
    dec byte [shake]
.t4: cmp byte [flashall],0
    je .t5
    dec byte [flashall]
.t5: cmp byte [state],ST_PREP
    jne .w
    dec word [prept]
    jnz .x
    call start_wave
    ret
.w: cmp byte [state],ST_WAVE
    jne .a
    call wave_tick
    ret
.a: cmp byte [state],ST_AVISO
    jne .x
    dec byte [avisot]
    jnz .x
    call start_prep
.x: ret

; =====================================================================
; teclas por estado  (al = tecla normalizada)
on_key:
    cmp al,'m'
    jne .nm
    xor byte [muted],1
    call speaker_off
    mov word [snd_seq],0
    ret
.nm: call in_game
    jnc .ng
    cmp al,'p'
    je .pause
    cmp al,27
    je .pause
    cmp byte [paused],0
    je .np
    cmp al,'q'
    jne .r
    mov byte [paused],0
    mov byte [state],ST_SEL
.r: ret
.pause: xor byte [paused],1
    ret
.np: cmp al,'f'
    jne .ng
    xor byte [fast],1
    mov si,s_vel1
    cmp byte [fast],0
    je .f1
    mov si,s_vel2
.f1: mov ax,1906h
    call toast
    ret
.ng: movzx bx,byte [state]
    shl bx,1
    jmp [key_tab+bx]
key_tab: dw k_menu,k_ctrl,k_sel,k_intro,k_prep,k_wave,k_none,k_wend,k_end,k_end,k_boss

k_none: ret
k_menu:
    cmp al,'w'
    jne .s
    add byte [menusel],2
    jmp .m
.s: cmp al,'s'
    jne .e
    inc byte [menusel]
.m: xor ah,ah
    mov al,[menusel]
    mov bl,3
    div bl
    mov [menusel],ah
    ret
.e: cmp al,27
    je .quit
    cmp al,13
    je .ok
    cmp al,' '
    jne .x
.ok: cmp byte [menusel],0
    jne .c
    mov byte [state],ST_SEL
    ret
.c: cmp byte [menusel],1
    jne .quit
    mov byte [state],ST_CTRL
    ret
.quit: mov byte [quit],1
.x: ret
k_ctrl:
    cmp al,13
    je .b
    cmp al,' '
    je .b
    cmp al,27
    je .b
    cmp al,'q'
    jne .x
.b: mov byte [state],ST_MENU
.x: ret
k_sel:
    mov bl,1
    cmp al,'d'
    je .mv
    mov bl,5
    cmp al,'a'
    je .mv
    mov bl,3
    cmp al,'w'
    je .mv
    cmp al,'s'
    je .mv
    cmp al,13
    je .go
    cmp al,' '
    je .go
    cmp al,'q'
    je .bk
    cmp al,27
    je .bk
    ret
.mv: mov al,[selidx]
    add al,bl
    xor ah,ah
    mov bl,6
    div bl
    mov [selidx],ah
    ret
.go: mov al,[selidx]
    call new_game
    mov byte [state],ST_INTRO
    mov si,seq_wave
    call play_seq
    ret
.bk: mov byte [state],ST_MENU
    ret
k_intro:
    cmp al,13
    je .go
    cmp al,' '
    je .go
    cmp al,'q'
    je .bk
    cmp al,27
    je .bk
    ret
.go: cmp byte [intropg],0              ; página 1 -> página 2 (mapa e chefe)
    jne .st
    mov byte [intropg],1
    ret
.st: call start_prep
    ret
.bk: cmp byte [intropg],0
    je .sel
    mov byte [intropg],0
    ret
.sel: mov byte [state],ST_SEL
    ret
k_boss:
    cmp al,13
    je .g
    cmp al,' '
    jne .x
.g: call start_prep
.x: ret
k_prep:
    cmp al,'w'
    jne .1
    cmp byte [cursy],1
    jbe .x
    dec byte [cursy]
    ret
.1: cmp al,'s'
    jne .2
    cmp byte [cursy],13
    jae .x
    inc byte [cursy]
    ret
.2: cmp al,'a'
    jne .3
    cmp byte [cursx],0
    je .x
    dec byte [cursx]
    ret
.3: cmp al,'d'
    jne .4
    cmp byte [cursx],15
    jae .x
    inc byte [cursx]
    ret
.4: cmp al,'1'
    jb .5
    cmp al,'4'
    ja .5
    sub al,'1'
    movzx bx,al
    mov si,[ph]
    cmp bl,[si+P_NTOW]
    jae .x
    mov al,[si+P_TOWT+bx]
    call unlocked
    jnc .lk
    mov [sel],al
    ret
.lk: call sb_reset
    push si
    mov si,s_libera
    call sb_str
    pop si
    shl bx,1
    mov ax,[si+P_TOWN+bx]
    call sb_num
    mov si,s_ptsganhos
    call sb_str
    mov ax,3C0Ah
    call toast_sb
    ret
.5: cmp al,' '
    jne .6
    call act_build
    ret
.6: cmp al,'v'
    jne .7
    call act_sell
    ret
.7: cmp al,'u'
    jne .8
    call act_upgrade
    ret
.8: cmp al,13
    jne .9
    call start_wave
    ret
.9: cmp al,'$'                        ; modo demonstração: +1000 pontos
    jne .10
    mov ax,1000
    mov cl,0
    call gain
    ret
.10: cmp al,'#'                       ; modo demonstração: pula para o chefe
    jne .x
    mov si,[ph]
    mov al,[si+P_NWAV]
    inc al
    mov [wave],al
    mov al,[si+P_OPENM]
    or [active],al
    mov si,s_pulachefe
    mov ax,3C08h
    call toast
.x: ret
k_wave:
    cmp al,'w'
    jne .1
    cmp byte [miray],1
    jbe .x
    dec byte [miray]
    ret
.1: cmp al,'s'
    jne .2
    cmp byte [miray],13
    jae .x
    inc byte [miray]
    ret
.2: cmp al,'a'
    jne .3
    cmp byte [mirax],0
    je .x
    dec byte [mirax]
    ret
.3: cmp al,'d'
    jne .4
    cmp byte [mirax],19
    jae .x
    inc byte [mirax]
    ret
.4: cmp al,' '
    jne .5
    call core_shoot
    ret
.5: cmp al,'r'
    jne .6
    mov byte [ammo],12
    mov byte [shotlock],30
    mov byte [ammot],0
    mov si,s_recarga
    mov ax,1906h
    call toast
    ret
.6: cmp al,'1'
    jb .x
    cmp al,'4'
    ja .x
    sub al,'1'
    mov bl,al
    call use_ab
.x: ret
k_wend:
    cmp al,13
    je .g
    cmp al,' '
    jne .x
.g: call after_wend
.x: ret
k_end:
    cmp al,13
    je .g
    cmp al,' '
    je .g
    cmp al,27
    jne .x
.g: mov byte [state],ST_SEL
.x: ret

; =====================================================================
; módulos das outras pessoas (o código entra aqui, os dados no .data delas)
%include "graficos.asm"        ; Pessoa 1
%include "inimigos.asm"        ; Pessoa 3
%include "torres_mapas.asm"    ; Pessoa 4

; =====================================================================
; dados da Pessoa 2 e dados gerados
section .data
s_bye:        db 'CORE DEFENSE - obrigado por jogar!',13,10,'$'
s_novatorre:  db 'NOVA TORRE: ',0
s_cedo:       db 'CEDO: +',0
s_vel1:       db 'VELOCIDADE 1X',0
s_vel2:       db 'VELOCIDADE 2X',0
s_recarga:    db 'RECARGA',0
s_libera:     db 'LIBERA COM ',0
s_ptsganhos:  db ' PTS GANHOS',0
s_pulachefe:  db 'DEMO: PROXIMA ONDA E O CHEFE',0
s_chefe_dp:   db 'CHEFE: ',0
seq_wave:   dw 392
            db 2
            dw 523
            db 2
            dw 0
seq_unlock: dw 659
            db 2
            dw 988
            db 3
            dw 0
seq_win:    dw 523
            db 2
            dw 659
            db 2
            dw 784
            db 2
            dw 1046
            db 5
            dw 0
seq_boss:   dw 110
            db 4
            dw 104
            db 4
            dw 98
            db 4
            dw 92
            db 8
            dw 0
seq_lose:   dw 392
            db 3
            dw 330
            db 3
            dw 262
            db 3
            dw 196
            db 7
            dw 0
%include "data.inc"

; =====================================================================
; =====================================================================
; variáveis (mapa de memória comum; o dono de cada uma está entre colchetes)
section .bss
bss_start:
bufseg:   resw 1                     ; [P1+P2]
seed:     resw 1                     ; [P2]
lasttick: resw 1                     ; [P2]
frm:      resw 1                     ; [P1+P3+P2]
state:    resb 1                     ; [P2+P1]
menusel:  resb 1                     ; [P2+P1]
selidx:   resb 1                     ; [P2+P1]
paused:   resb 1                     ; [P2+P1]
fast:     resb 1                     ; [P2+P1]
quit:     resb 1                     ; [P2]
muted:    resb 1                     ; [P2]
done:     resb 1                     ; [P1+P2]
snd_t:    resb 1                     ; [P2]
snd_seq:  resw 1                     ; [P2]
lastkill: resw 1                     ; [P3]
spk:      resb 1                     ; [P1+P2]
rcmode:   resb 1                     ; [P1]
rccol:    resb 1                     ; [P1]
rcmap:    resw 1                     ; [P1]
; temporários de desenho
fr_x:     resw 1                     ; [P1]
fr_y:     resw 1                     ; [P1]
fr_h:     resw 1                     ; [P1]
sp_x:     resw 1                     ; [P1]
sp_y:     resw 1                     ; [P1]
sp_w:     resb 1                     ; [P1]
sp_h:     resb 1                     ; [P1]
sp_i:     resb 1                     ; [P1]
sp_j:     resb 1                     ; [P1]
dt_x:     resw 1                     ; [P1]
dt_y:     resw 1                     ; [P1]
dt_c:     resb 1                     ; [P1]
dt_k:     resb 1                     ; [P1]
dt_r:     resb 1                     ; [P1]
dt_cc:    resb 1                     ; [P1]
ln_x0:    resw 1                     ; [P1]
ln_y0:    resw 1                     ; [P1]
ln_x1:    resw 1                     ; [P1]
ln_y1:    resw 1                     ; [P1]
ln_dx:    resw 1                     ; [P1]
ln_dy:    resw 1                     ; [P1]
ln_sx:    resw 1                     ; [P1]
ln_sy:    resw 1                     ; [P1]
ln_e:     resw 1                     ; [P1]
ln_c:     resb 1                     ; [P1]
c_x:      resw 1                     ; [P1]
c_y:      resw 1                     ; [P1]
c_r:      resw 1                     ; [P1]
c_rr:     resw 1                     ; [P1]
c_col:    resb 1                     ; [P1]
numbuf:   resb 8                     ; [P2]
strbuf:   resb 48                    ; [P1+P2]
sbpos:    resw 1                     ; [P2]
chbuf:    resb 2                     ; [P1]
um_tx:    resb 1                     ; [P1]
um_ty:    resb 1                     ; [P1]
cx_:      resw 1                     ; [P1]
cy_:      resw 1                     ; [P1]
col:      resb 1                     ; [P1]
sx_:      resw 1                     ; [P1]
sy_:      resw 1                     ; [P1]
sc_:      resw 1                     ; [P1]
sf_x:     resw 1                     ; [P1]
sf_y:     resw 1                     ; [P1]
sf_c:     resb 1                     ; [P1]
pp_x:     resw 1                     ; [P1]
pp_y:     resw 1                     ; [P1]
pp_bit:   resb 1                     ; [P1]
pp_blink: resb 1                     ; [P1]
hb_x:     resw 1                     ; [P1]
hb_y:     resw 1                     ; [P1]
hb_w:     resw 1                     ; [P1]
hq_x:     resw 1                     ; [P1]
hq_y:     resw 1                     ; [P1]
ab_x:     resw 1                     ; [P1]
pn_y:     resw 1                     ; [P1]
pn_t:     resb 1                     ; [P1]
pn_ok:    resb 1                     ; [P1]
rg_x:     resw 1                     ; [P1]
rg_y:     resw 1                     ; [P1]
rg_w:     resw 1                     ; [P1]
ts_x:     resw 1                     ; [P1]
ts_w:     resw 1                     ; [P1]
b_x:      resw 1                     ; [P1]
b_y:      resw 1                     ; [P1]
b_c:      resb 1                     ; [P1]
g_before: resw 1                     ; [P2]
flags:    resb 1                     ; [P3+P4+P2]
sp_mask:  resb 1                     ; [P3]
sp_r1:    resb 1                     ; [P3]
mv_s:     resw 1                     ; [P3]
ex_c:     resw 1                     ; [P3]
pass:     resb 1                     ; [P3]
changed:  resb 1                     ; [P3]
tw_n:     resw 1                     ; [P4]
tw_sp:    resw 1                     ; [P4]
tf_t:     resw 1                     ; [P4]
tf_tab:   resw 1                     ; [P4]
tf_x:     resb 1                     ; [P4]
tf_y:     resb 1                     ; [P4]
tf_dmg:   resw 1                     ; [P4]
tf_any:   resb 1                     ; [P4]
tf_best:  resw 1                     ; [P4]
tf_bd:    resw 1                     ; [P4]
remv:     resw MAXE                  ; [P3]
ext:      resw 1                     ; registro EXT da fase atual [P3+P1+P2+P4]
bimm:     resb 1                     ; [P3]
bk_n:     resb 1                     ; [P3]
bk_best:  resw 1                     ; [P3]
bk_bd:    resw 1                     ; [P3]
bk_sp:    resw 1                     ; [P3]
qcnt:     resb 4                     ; [P4]
bb_x:     resw 1                     ; [P1]
bb_y:     resw 1                     ; [P1]
bb_w:     resw 1                     ; [P1]
bb_c:     resw 1                     ; [P1]
fn_cx:    resw 1                     ; [P1]
fn_cy:    resw 1                     ; [P1]
; ---- estado da partida (zerado em new_game) ----
ph:       resw 1                     ; [P1+P2+P3+P4]
phidx:    resb 1                     ; [P1+P2+P4]
game_start:
vida:     resw 1                     ; [P1+P3+P2]
pontos:   resw 1                     ; [P4+P1+P2+P3]
ganhos:   resw 1                     ; [P2]
wave:     resb 1                     ; [P2+P1+P3]
active:   resb 1                     ; [P3+P2+P1]
cursx:    resb 1                     ; [P2+P1+P4]
cursy:    resb 1                     ; [P2+P1+P4]
mirax:    resb 1                     ; [P2+P4+P1]
miray:    resb 1                     ; [P2+P4+P1]
sel:      resb 1                     ; [P2+P1+P4]
prept:    resw 1                     ; [P2+P1]
ammo:     resb 1                     ; [P4+P1+P2]
ammot:    resb 1                     ; [P4+P2]
shotlock: resb 1                     ; [P4+P1+P2]
ab:       resb 4                     ; [P4+P1+P2+P3]
heat:     resw 1                     ; [P4+P1]
hot:      resb 1                     ; [P4+P1]
toast_c:  resb 1                     ; [P1+P2]
toast_l:  resb 1                     ; [P2+P1]
toastbuf: resb 40                    ; [P1+P2]
shake:    resb 1                     ; [P3+P2]
coreflash: resb 1                    ; [P2+P1+P3]
wavegain: resw 1                     ; [P2+P1]
bonus:    resw 1                     ; [P1+P2]
newtower: resb 1                     ; [P1+P2]
avisot:   resb 1                     ; [P2]
quad:     resb 1                     ; [P4+P1+P2+P3]
qt:       resb 1                     ; [P2+P4]
flashall: resb 1                     ; [P4+P2+P1]
intropg:  resb 1                     ; 0 = regras, 1 = mapa e chefe [P2+P1]
bossp:    resw 1                     ; ponteiro do chefe vivo (0 = nenhum) [P3+P1]
bt:       resw 1                     ; relógio do chefe [P3+P4]
bhalf:    resb 1                     ; [P3]
el_ch:    resw 1                     ; carga do elemento do mapa [P4+P1]
el_on:    resb 1                     ; teclado: tecla acesa [P4+P1+P2]
el_kx:    resb 1                     ; [P4+P1]
el_ky:    resb 1                     ; [P4+P1]
el_life:  resb 1                     ; [P4+P1]
el_t:     resb 1                     ; [P4+P2]
el_last:  resb 1                     ; [P4+P2]
fan:      resb 1                     ; ventoinhas no máximo (quadros) [P4+P1+P3]
seekh:    resb 1                     ; cabeça do HD presa pela busca (quadros) [P1+P2+P4]
spawners: resb 4*8                   ; [P2+P3]
towers:   resb MAXT*TSZ              ; [P4+P3+P1]
enemies:  resb MAXE*ESZ              ; [P4+P3+P1+P2]
fxs:      resb MAXFX*FXSZ            ; [P1+P2]
parts:    resb MAXP*PSZ              ; [P1+P2]
game_end:
bss_end:
