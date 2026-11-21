; =====================================================================
; torres_mapas.asm  ·  PESSOA 4 — TORRES, COMBATE E MAPAS
;
;   - Torres: construir, vender, melhorar, cursor nos soquetes (act_*)
;   - Combate: tower_fire/tf_apply, tiro do núcleo (core_shoot), habilidades (use_ab)
;   - Regras dos componentes: cabeça do HD (quad_of), calor da GPU (heat_add)
;   - Elementos do mapa: el_tick, el_use e a ação de cada fase (el_ram ... el_cpu)
;   - Quadro da onda: wt_towers. Dono do vetor towers[16]
;
; Parte do Core Defense x86. Montado junto pelo main.asm:
;   nasm -f bin main.asm -o CORE.COM
; =====================================================================

section .text


quad_of:                              ; al = x, ah = y (célula) -> al = quadrante
    cmp al,8
    jb .left
    cmp ah,7
    ja .br
    xor al,al
    ret
.br: mov al,1
    ret
.left: cmp ah,7
    ja .bl
    mov al,3
    ret
.bl: mov al,2
    ret

heat_add:                             ; ax = calor (x10)
    pusha
    add [heat],ax
    cmp word [heat],1000
    jb .x
    cmp byte [hot],0
    jne .x
    mov byte [hot],60
    mov word [heat],1000
    mov si,s_quente
    mov ax,2D0Ch
    call toast
    mov bx,200
    mov cl,4
    call beep
.x: popa
    ret

; =====================================================================
; elemento do mapa: peça do cenário que o jogador ativa atirando nela
in_box:                               ; al = x, ah = y, di = caixa -> CF=1 se dentro
    cmp al,[di]
    jb .no
    cmp al,[di+2]
    ja .no
    cmp ah,[di+1]
    jb .no
    cmp ah,[di+3]
    ja .no
    stc
    ret
.no: clc
    ret

el_tick:                              ; uma vez por quadro de onda
    cmp byte [fan],0
    je .f
    dec byte [fan]
.f: mov si,[ext]
    mov bx,[si+X_KEYS]
    test bx,bx
    jz .chg
    ; teclado: uma tecla acende, espera o tiro e trava se for ignorada
    cmp byte [el_on],0
    je .off
    dec byte [el_life]
    jnz .x
    mov byte [el_on],0
    mov byte [el_t],0
    xor al,al                         ; tecla presa: auto-repetição solta um bug
    xor bl,bl
    xor cx,cx
    call spawn
    mov si,s_presa
    mov ax,2D08h
    call toast
    mov bx,90
    mov cl,2
    call beep
    ret
.off: inc byte [el_t]
    cmp byte [el_t],90
    jb .x
    mov byte [el_t],0
    movzx cx,byte [bx]
.pick: call rnd
    xor dx,dx
    div cx
    cmp dl,[el_last]
    je .pick
    mov [el_last],dl
    shl dx,1
    add bx,dx
    mov al,[bx+1]
    mov [el_kx],al
    mov al,[bx+2]
    mov [el_ky],al
    mov byte [el_on],1
    mov byte [el_life],70
    mov bx,1400
    mov cl,1
    call beep
    ret
.chg: mov ax,[si+X_CHG]               ; demais fases: carga
    cmp [el_ch],ax
    jae .x
    inc word [el_ch]
    cmp [el_ch],ax
    jne .x
    call sb_reset
    push si
    mov si,[si+X_ELN]
    call sb_str
    mov si,s_pronto
    call sb_str
    mov ax,2806h
    call toast_sb
    mov si,seq_unlock
    call play_seq
    pop si
.x: ret

el_use:                               ; tiro do núcleo na mira -> CF=1 se acertou o elemento
    pusha
    mov si,[ext]
    mov bx,[si+X_KEYS]
    test bx,bx
    jz .box
    cmp byte [el_on],0
    je .no
    mov al,[mirax]
    cmp al,[el_kx]
    jne .no
    mov al,[miray]
    cmp al,[el_ky]
    jne .no
    mov di,enemies                    ; DEL: 3 de dano em volta (9 no chefe)
.dl: cmp byte [di+E_ACT],0
    je .dn
    call ecell
    sub al,[el_kx]
    jns .d1
    neg al
.d1: cmp al,2
    ja .dn
    mov al,ah
    sub al,[el_ky]
    jns .d2
    neg al
.d2: cmp al,2
    ja .dn
    mov ax,3
    cmp byte [di+E_TYPE],ET_BOSS
    jne .d3
    mov ax,9
.d3: call hit
.dn: add di,ESZ
    cmp di,enemies+MAXE*ESZ
    jb .dl
    mov al,2
    mov ah,9
    mov bl,[el_kx]
    mov bh,[el_ky]
    mov cl,2
    mov dl,6
    call add_fx
    mov byte [el_on],0
    mov byte [el_t],0
    mov si,s_del
    mov ax,1905h
    call toast
    mov si,seq_ab
    call play_seq
    jmp .yes
.box: mov al,[mirax]
    mov ah,[miray]
    lea di,[si+X_BOX]
    call in_box
    jc .inb
    lea di,[si+X_BOX2]
    call in_box
    jnc .no
.inb: mov ax,[si+X_CHG]
    cmp [el_ch],ax
    jae .ready
    mov ax,[el_ch]                    ; ainda carregando: mostra quanto falta
    mov cx,100
    mul cx
    div word [si+X_CHG]
    push ax
    call sb_reset
    mov si,[si+X_ELN]
    call sb_str
    mov al,' '
    call sb_chr
    pop ax
    call sb_num
    mov al,'%'
    call sb_chr
    mov ax,190Ah
    call toast_sb
    jmp .yes
.ready: mov word [el_ch],0
    mov si,seq_ab
    call play_seq
    movzx bx,byte [phidx]
    shl bx,1
    call [el_fn+bx]
.yes: popa
    stc
    ret
.no: popa
    clc
    ret
el_fn: dw el_none,el_ram,el_hd,el_ssd,el_gpu,el_cpu
el_none: ret

el_ram:                               ; REFRESH: todos voltam para a entrada
    mov di,enemies
.l: cmp byte [di+E_ACT],0
    je .n
    mov byte [di+E_SLOW],0
    and byte [di+E_FLAGS],0F5h
    cmp byte [di+E_TYPE],ET_BOSS
    jne .z
    mov bl,[di+E_ROUTE]               ; o MEMORY LEAK só volta 1/4
    call route_rec
    mov ax,[si+2]
    shr ax,2
    sub [di+E_D],ax
    jae .p
.z: mov word [di+E_D],0
.p: call epos
.n: add di,ESZ
    cmp di,enemies+MAXE*ESZ
    jb .l
    mov byte [flashall],6
    mov si,s_refresh
    mov ax,2D06h
    call toast
    ret

el_hd:                                ; BUSCA: cabeça vai para o quadrante mais cheio
    mov dword [qcnt],0
    mov di,enemies
.l: cmp byte [di+E_ACT],0
    je .n
    call ecell
    call quad_of
    movzx bx,al
    mov al,1
    cmp byte [di+E_TYPE],ET_BOSS
    jne .a
    mov al,5
.a: add [qcnt+bx],al
.n: add di,ESZ
    cmp di,enemies+MAXE*ESZ
    jb .l
    xor bx,bx
    xor cx,cx                         ; cl = melhor quadrante, ch = contagem
.m: mov al,[qcnt+bx]
    cmp al,ch
    jbe .mn
    mov ch,al
    mov cl,bl
.mn: inc bx
    cmp bx,4
    jb .m
    mov [quad],cl
    mov byte [qt],0
    mov byte [seekh],160
    call sb_reset
    mov si,s_busca
    call sb_str
    movzx ax,byte [quad]
    inc ax
    call sb_num
    mov ax,2806h
    call toast_sb
    ret

el_ssd:                               ; NIVELAMENTO: cada célula recupera 1 uso
    xor dx,dx
    mov bx,towers
    mov cx,MAXT
.l: cmp byte [bx+T_USE],0
    je .u
    cmp byte [bx+T_USE],2
    jb .d
    inc dl
.d: dec byte [bx+T_USE]
.u: mov byte [bx+T_LOCK],0
    add bx,TSZ
    dec cx
    jnz .l
    mov byte [flashall],4
    call sb_reset
    test dl,dl
    jz .ok
    mov si,s_nivel
    call sb_str
    movzx ax,dl
    call sb_num
    mov si,s_soqvolt
    call sb_str
    jmp .t
.ok: mov si,s_nivok
    call sb_str
.t: mov ax,3206h
    call toast_sb
    ret

el_gpu:                               ; VENTOINHAS: calor zera e não sobe por 5 s
    mov word [heat],0
    mov byte [hot],0
    mov byte [fan],100
    mov si,s_vent
    mov ax,2806h
    call toast
    ret

el_cpu:                               ; FLUSH: quem está no pipeline volta 8 casas
    xor dx,dx
    mov di,enemies
.l: cmp byte [di+E_ACT],0
    je .n
    mov bl,[di+E_ROUTE]
    call route_rec
    mov ax,[si+2]
    sub ax,[di+E_D]
    cmp ax,1408
    ja .n
    mov ax,1024
    cmp byte [di+E_TYPE],ET_BOSS
    jne .a
    mov ax,512
.a: sub [di+E_D],ax
    jae .b
    mov word [di+E_D],0
.b: and byte [di+E_FLAGS],0F5h
    mov byte [di+E_STOP],0
    inc dx
    call epos
.n: add di,ESZ
    cmp di,enemies+MAXE*ESZ
    jb .l
    mov byte [flashall],4
    push dx
    call sb_reset
    mov si,s_flush
    call sb_str
    pop ax
    call sb_num
    mov si,s_forapipe
    call sb_str
    mov ax,2D06h
    call toast_sb
    ret

wt_towers:                            ; [P4] torres atirando, calor da GPU, munição e habilidades
    mov si,[ph]
    movzx cx,byte [si+P_NSLOT]
    mov [tw_n],cx
    mov ax,[si+P_SLOTS]
    mov [tw_sp],ax
    mov bx,towers
.tl: cmp byte [bx+T_TYPE],0
    je .tn
    cmp byte [bx+T_FLASH],0
    je .t0
    dec byte [bx+T_FLASH]
.t0: cmp byte [bx+T_LOCK],0
    je .t1
    dec byte [bx+T_LOCK]
    jmp .tn
.t1: mov dl,4                         ; taxa de recarga (1/4 tick)
    cmp byte [ab],0
    je .t2
    shl dl,1
.t2: test byte [flags],F_HEAD
    jz .t3
    mov si,[tw_sp]
    mov al,[si]
    mov ah,[si+1]
    call quad_of
    cmp al,[quad]
    jne .t3
    shl dl,1
.t3: cmp byte [hot],0
    je .t4
    shr dl,1
.t4: cmp [bx+T_CD],dl
    jbe .fire2
    sub [bx+T_CD],dl
    jmp .tn
.fire2: mov byte [bx+T_CD],0
    call tower_fire
.tn: add bx,TSZ
    add word [tw_sp],2
    dec word [tw_n]
    jnz .tl
    ; ---- calor (GPU) ----
    test byte [flags],F_HEAT
    jz .nh
    cmp byte [hot],0
    je .hd
    dec byte [hot]
    jnz .nh
    mov word [heat],400
    jmp .nh
.hd: sub word [heat],6
    jns .nh
    mov word [heat],0
.nh:
    ; ---- munição e habilidades ----
    cmp byte [ammo],12
    jae .am
    inc byte [ammot]
    cmp byte [ammot],20
    jb .am
    inc byte [ammo]
    mov byte [ammot],0
.am: cmp byte [shotlock],0
    je .ab
    dec byte [shotlock]
.ab: mov si,ab
.abl: cmp byte [si],0
    je .abn
    dec byte [si]
.abn: inc si
    cmp si,ab+4
    jb .abl
    ret

tower_fire:                           ; bx = torre, [tw_sp] = coordenadas do soquete
    pusha
    mov [tf_t],bx
    movzx di,byte [bx+T_TYPE]
    shl di,3
    add di,tower_tab
    mov [tf_tab],di
    mov si,[tw_sp]
    mov al,[si]
    mov [tf_x],al
    mov al,[si+1]
    mov [tf_y],al
    ; dano
    movzx ax,byte [di+2]
    movzx cx,byte [bx+T_LVL]
    dec cx
    add ax,cx
    test byte [flags],F_AREA
    jz .d1
    cmp byte [di+6],0
    je .d1
    inc ax
.d1: cmp byte [ab+2],0
    je .d2
    shl ax,1
.d2: mov [tf_dmg],ax
    mov byte [tf_any],0
    mov word [tf_best],0
    mov word [tf_bd],0
    mov di,enemies
.el: cmp byte [di+E_ACT],0
    je .en
    call ecell
    mov si,[tf_tab]
    mov dl,[si+3]                     ; alcance
    sub al,[tf_x]
    jns .a1
    neg al
.a1: cmp al,dl
    ja .en
    mov al,ah
    sub al,[tf_y]
    jns .a2
    neg al
.a2: cmp al,dl
    ja .en
    ; no alcance
    cmp byte [si+6],0
    je .single
    mov byte [tf_any],1
    call tf_apply
    jmp .en
.single: mov ax,[di+E_D]
    cmp word [tf_best],0
    je .take
    cmp ax,[tf_bd]
    jbe .en
.take: mov [tf_best],di
    mov [tf_bd],ax
.en: add di,ESZ
    cmp di,enemies+MAXE*ESZ
    jb .el
    mov si,[tf_tab]
    cmp byte [si+6],0
    je .sg
    cmp byte [tf_any],0
    je .x
    mov al,2                          ; anel do Purge
    mov ah,9
    mov bl,[tf_x]
    mov bh,[tf_y]
    mov cl,[si+3]
    mov dl,4
    call add_fx
    jmp .shot
.sg: mov di,[tf_best]
    test di,di
    jz .x
    ; traço do tiro
    mov al,1
    mov ah,5
    cmp byte [si+5],0
    je .tc
    mov ah,6
.tc: mov bl,[tf_x]
    shl bl,3
    add bl,4
    mov bh,[tf_y]
    shl bh,3
    add bh,3
    mov cl,[di+E_X]
    add cl,4
    mov ch,[di+E_Y]
    add ch,4
    mov dl,3
    call add_fx
    call tf_apply
.shot: mov bx,[tf_t]
    mov si,[tf_tab]
    mov al,[si+4]
    shl al,2
    mov [bx+T_CD],al
    mov byte [bx+T_FLASH],2
    test byte [flags],F_HEAT
    jz .x
    cmp byte [fan],0                  ; ventoinhas no máximo: calor não sobe
    jne .x
    mov ax,15
    cmp byte [si+6],0
    je .h1
    mov ax,30
.h1: cmp byte [ab],0
    je .h2
    shl ax,1
.h2: add [heat],ax
    cmp word [heat],1000
    jb .x
    cmp byte [hot],0
    jne .x
    mov byte [hot],60
    mov word [heat],1000
    mov si,s_quente
    mov ax,2D0Ch
    call toast
    mov bx,200
    mov cl,4
    call beep
.x: popa
    ret
tf_apply:                             ; aplica dano/lentidão da torre atual no inimigo di
    push ax
    push si
    mov si,[tf_tab]
    mov al,[si+5]
    test al,al
    jz .ns
    cmp byte [di+E_TYPE],ET_BOSS
    jne .sl
    push si
    mov si,[ext]
    test byte [si+X_BFL],BF_NOSLOW
    pop si
    jnz .ns
.sl: mov [di+E_SLOW],al
.ns: mov ax,[tf_dmg]
    call hit
    pop si
    pop ax
    ret

; ---- ações do jogador ----
cursor_slot:                          ; -> bx = índice do soquete sob o cursor, CF=1 se achou
    push ax
    push cx
    push si
    mov si,[ph]
    movzx cx,byte [si+P_NSLOT]
    mov si,[si+P_SLOTS]
    xor bx,bx
.l: cmp bx,cx
    jae .no
    mov al,[si]
    cmp al,[cursx]
    jne .n
    mov al,[si+1]
    cmp al,[cursy]
    je .y
.n: add si,2
    inc bx
    jmp .l
.y: stc
    jmp .x
.no: clc
.x: pop si
    pop cx
    pop ax
    ret

act_build:
    pusha
    call cursor_slot
    jc .s
    mov si,s_soquete
    mov ax,2D0Ah
    call toast
    jmp .x
.s: shl bx,3
    add bx,towers
    cmp byte [bx+T_TYPE],0
    je .free
    call sb_reset
    movzx di,byte [bx+T_TYPE]
    shl di,1
    mov si,[tower_name+di]
    call sb_str
    mov si,s_nv
    call sb_str
    movzx ax,byte [bx+T_LVL]
    call sb_num
    mov si,s_vu
    call sb_str
    mov ax,3C0Bh
    call toast_sb
    jmp .x
.free: mov si,[ph]
    test byte [si+P_FLAGS],F_WEAR
    jz .w
    cmp byte [bx+T_USE],2
    jb .w
    mov si,s_queimado
    mov ax,2D08h
    call toast
    jmp .x
.w: mov al,[sel]
    call unlocked
    jc .u
    mov si,s_bloq
    mov ax,2D0Ah
    call toast
    jmp .x
.u: movzx di,byte [sel]
    shl di,3
    mov ax,[tower_tab+di]
    cmp [pontos],ax
    jae .pay
    call no_money
    jmp .x
.pay: sub [pontos],ax
    mov cl,[sel]
    mov [bx+T_TYPE],cl
    mov byte [bx+T_LVL],1
    mov byte [bx+T_CD],0
    mov byte [bx+T_LOCK],0
    mov [bx+T_INV],ax
    mov si,[ph]
    test byte [si+P_FLAGS],F_WEAR
    jz .snd
    inc byte [bx+T_USE]
.snd: mov si,seq_build
    call play_seq
.x: popa
    ret
no_money:
    push si
    push ax
    mov si,s_semponto
    mov ax,2D08h
    call toast
    mov bx,90
    mov cl,1
    call beep
    pop ax
    pop si
    ret

act_sell:
    pusha
    call cursor_slot
    jnc .none
    shl bx,3
    add bx,towers
    cmp byte [bx+T_TYPE],0
    je .none
    mov ax,[bx+T_INV]
    imul ax,6
    xor dx,dx
    mov cx,10
    div cx
    add [pontos],ax
    mov si,[ph]
    test byte [si+P_FLAGS],F_CAP
    jz .c
    mov cx,[si+P_CAP]
    cmp [pontos],cx
    jbe .c
    mov [pontos],cx
.c: mov byte [bx+T_TYPE],0
    call sb_reset
    mov si,s_vendida
    call sb_str
    call sb_num
    mov ax,2D05h
    call toast_sb
    mov si,[ph]
    test byte [si+P_FLAGS],F_WEAR
    jz .x
    cmp byte [bx+T_USE],2
    jb .x
    mov si,s_queimou
    mov ax,2D08h
    call toast
    jmp .x
.none: mov si,s_nada
    mov ax,2D0Ah
    call toast
.x: popa
    ret

act_upgrade:
    pusha
    call cursor_slot
    jnc .none
    shl bx,3
    add bx,towers
    cmp byte [bx+T_TYPE],0
    je .none
    cmp byte [bx+T_LVL],2
    jb .ok
    mov si,s_jank2
    mov ax,2D0Ah
    call toast
    jmp .x
.ok: movzx di,byte [bx+T_TYPE]
    shl di,3
    mov ax,[tower_tab+di]
    cmp [pontos],ax
    jae .pay
    call no_money
    jmp .x
.pay: sub [pontos],ax
    add [bx+T_INV],ax
    mov byte [bx+T_LVL],2
    mov si,s_nivel2
    mov ax,2D06h
    call toast
    mov si,seq_build
    call play_seq
    jmp .x
.none: mov si,s_escolha_t
    mov ax,2D0Ah
    call toast
.x: popa
    ret

core_shoot:
    pusha
    cmp byte [ammo],0
    je .empty
    cmp byte [shotlock],0
    je .ok
.empty: mov bx,90
    mov cl,1
    call beep
    jmp .x
.ok: dec byte [ammo]
    mov bx,880
    mov cl,1
    call beep
    mov al,3
    mov bl,[mirax]
    mov bh,[miray]
    mov dl,4
    call add_fx
    call el_use                       ; acertou o elemento do mapa?
    jc .x
    mov di,enemies
.l: cmp byte [di+E_ACT],0
    je .n
    call ecell
    cmp byte [di+E_TYPE],ET_BOSS
    je .bs
    cmp al,[mirax]
    jne .n
    cmp ah,[miray]
    jne .n
    jmp .hh
.bs: sub al,[mirax]                   ; chefe: alvo de 3x3 células
    jns .b1
    neg al
.b1: cmp al,1
    ja .n
    mov al,ah
    sub al,[miray]
    jns .b2
    neg al
.b2: cmp al,1
    ja .n
.hh: mov ax,2
    call hit
.n: add di,ESZ
    cmp di,enemies+MAXE*ESZ
    jb .l
.x: popa
    ret

use_ab:                               ; bl = 0..3
    pusha
    movzx bx,bl
    mov si,[ph]
    mov al,[si+P_ABIL]
    bt ax,bx
    jc .ok
    call sb_reset
    mov di,bx
    shl di,1
    mov si,[ab_name+di]
    call sb_str
    mov si,s_bloqaqui
    call sb_str
    mov ax,2D0Ah
    call toast_sb
    jmp .x
.ok: cmp byte [ab+bx],0
    jne .x
    mov di,bx
    shl di,1
    mov ax,[ab_cost+di]
    cmp [pontos],ax
    jae .pay
    call sb_reset
    mov si,s_precisa
    call sb_str
    call sb_num
    mov si,s_pontos_sp
    call sb_str
    mov ax,2D08h
    call toast_sb
    jmp .x
.pay: sub [pontos],ax
    push si
    mov si,seq_ab
    call play_seq
    pop si
    cmp bx,3
    jne .tm
    mov di,enemies
.av: cmp byte [di+E_ACT],0
    je .avn
    cmp byte [di+E_TYPE],5
    je .avn
    mov ax,1
    call hit
.avn: add di,ESZ
    cmp di,enemies+MAXE*ESZ
    jb .av
    mov byte [flashall],4
    mov si,s_antiv
    mov ax,2D06h
    call toast
    jmp .x
.tm: mov byte [ab+bx],ABT
    call sb_reset
    mov di,bx
    shl di,1
    mov si,[ab_name+di]
    call sb_str
    mov al,'!'
    call sb_chr
    mov ax,1E05h
    call toast_sb
.x: popa
    ret

; ---------------------------------------------------------------------
; dados da Pessoa 4
section .data
s_quente:     db 'SUPERAQUECEU!',0
s_soquete:    db 'ESCOLHA UM SOQUETE',0
s_nv:         db ' NV',0
s_vu:         db '  V VENDE U MELHORA',0
s_queimado:   db 'SOQUETE QUEIMADO',0
s_queimou:    db 'SOQUETE QUEIMOU',0
s_bloq:       db 'TORRE BLOQUEADA',0
s_semponto:   db 'PONTOS INSUFICIENTES',0
s_vendida:    db 'VENDIDA: +',0
s_nada:       db 'NADA PARA VENDER',0
s_jank2:      db 'JA ESTA NO NIVEL 2',0
s_nivel2:     db 'NIVEL 2: DANO +1',0
s_escolha_t:  db 'ESCOLHA UMA TORRE',0
s_bloqaqui:   db ' BLOQUEADA AQUI',0
s_precisa:    db 'PRECISA DE ',0
s_pontos_sp:  db ' PONTOS',0
s_antiv:      db 'ANTIVIRUS!',0
s_pronto:     db ' PRONTO',0
s_del:        db 'DEL!',0
s_presa:      db 'TECLA PRESA: +1 BUG',0
s_refresh:    db 'REFRESH: A RAM ESQUECEU',0
s_busca:      db 'BUSCA: TRILHA ',0
s_nivel:      db 'NIVELAMENTO: ',0
s_soqvolt:    db ' SOQUETES VOLTARAM',0
s_nivok:      db 'NIVELAMENTO: CELULAS OK',0
s_vent:       db 'VENTOINHAS NO MAXIMO',0
s_flush:      db 'FLUSH: ',0
s_forapipe:   db ' FORA DO PIPELINE',0
seq_build:  dw 523
            db 1
            dw 784
            db 2
            dw 0
seq_ab:     dw 440
            db 1
            dw 660
            db 1
            dw 880
            db 1
            dw 0
