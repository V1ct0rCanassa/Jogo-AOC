; =====================================================================
; inimigos.asm  ·  PESSOA 3 — INIMIGOS E CHEFES
;
;   - Rotas: route_rec, epos, ecell (distância em 1/16 px -> posição)
;   - Vetor de inimigos: spawn, hit, kill
;   - Quadro da onda: wt_spawners (ondas), wt_pipeline (CPU), wt_move (movimento)
;   - Os 6 chefes: spawn_boss, boss_tick e as habilidades de cada um
;   - Dono do vetor enemies[64]: só este módulo escreve nele
;
; Parte do Core Defense x86. Montado junto pelo main.asm:
;   nasm -f bin main.asm -o CORE.COM
; =====================================================================

section .text


; ---- rotas e inimigos ----
route_rec:                            ; acha a rota entre a,b,c e d  bl = numero da rota -> si = endereco  da ficha 
    push ax
    mov si,[ph]
    mov si,[si+P_ROUTS]
    movzx ax,bl
    imul ax,6
    add si,ax
    pop ax
    ret

epos:                                 ; di = inimigo -> calcula E_X, E_Y
    pusha
    mov bl,[di+E_ROUTE]
    call route_rec
    mov bx,[si]
    mov cx,[si+2]
    mov ax,[di+E_D]
    cmp ax,cx
    jbe .ok
    mov ax,cx
.ok: mov dx,ax
    shr dx,7
    and ax,127
    shr ax,4
    shl dx,1
    add bx,dx
    movzx cx,byte [bx]
    movzx dx,byte [bx+1]
    movzx si,byte [bx+2]
    sub si,cx
    imul si,ax
    shl cx,3
    add cx,si
    mov [di+E_X],cl
    movzx si,byte [bx+3]
    sub si,dx
    imul si,ax
    shl dx,3
    add dx,si
    mov [di+E_Y],dl
    popa
    ret

ecell:                                ; di = inimigo -> al = célula x, ah = célula y
    mov al,[di+E_X]
    add al,4
    shr al,3
    mov ah,[di+E_Y]
    add ah,4
    shr ah,3
    ret

spawn:                                ; al = tipo, bl = rota, cx = distância inicial
    cmp al,ET_BOSS
    jne .norm
    jmp spawn_boss
.norm: pusha
    mov di,enemies
    mov dx,MAXE
.f: cmp byte [di+E_ACT],0
    je .got
    add di,ESZ
    dec dx
    jnz .f
    jmp .x
.got: mov dword [di],0
    mov dword [di+4],0
    mov dword [di+8],0
    mov dword [di+12],0
    mov byte [di+E_ACT],1
    mov [di+E_TYPE],al
    mov [di+E_ROUTE],bl
    cmp cx,0
    jge .d0
    xor cx,cx
.d0: mov [di+E_D],cx
    cmp al,5
    jne .ns
    mov byte [di+E_FLAGS],1
.ns: mov si,[ph]
    mov bx,[si+P_HP]
    movzx cx,byte [wave]
    dec cx
    imul cx,6
    movzx dx,al
    add cx,dx
    add bx,cx
    movzx cx,byte [bx]
    mov [di+E_HP],cx
    mov [di+E_MAX],cx
    movzx bx,al
    mov cl,[si+P_ESPD+bx]
    mov [di+E_SPD],cl
    call epos
.x: popa
    ret

hit:                                  ; di = inimigo, ax = dano
    cmp byte [di+E_ACT],0
    je .x
    test byte [di+E_FLAGS],1
    jz .n
    and byte [di+E_FLAGS],0FEh
    mov byte [di+E_FLASH],3
    ret
.n: cmp byte [di+E_TYPE],ET_BOSS
    jne .n2
    call boss_armor
.n2: sub [di+E_HP],ax
    mov byte [di+E_FLASH],2
    cmp word [di+E_HP],0
    jg .x
    call kill
.x: ret

kill:                                 ; di = inimigo
    pusha
    mov byte [di+E_ACT],0
    cmp byte [di+E_TYPE],ET_BOSS
    jne .nb
    call boss_killed
    jmp .x
.nb: mov si,[ph]
    movzx bx,byte [di+E_TYPE]
    shl bx,1
    mov ax,[si+P_EPTS+bx]
    mov cl,1
    call gain
    movzx ax,byte [di+E_X]
    add ax,4
    movzx bx,byte [di+E_Y]
    add bx,4
    movzx si,byte [di+E_TYPE]
    mov cl,[enemy_col+si]
    call burst
    mov ax,[frm]
    sub ax,[lastkill]
    cmp ax,3
    jb .ns
    mov ax,[frm]
    mov [lastkill],ax
    mov bx,330
    mov cl,1
    call beep
.ns: cmp byte [di+E_TYPE],3
    jne .x
    mov si,[ph]
    movzx dx,byte [si+P_WORM]
    mov cx,[di+E_D]
    mov bl,[di+E_ROUTE]
.w: test dx,dx
    jz .x
    mov al,0
    call spawn
    sub cx,80
    dec dx
    jmp .w
.x: popa
    ret

; =====================================================================
; chefe da fase (um por vez, ponteiro em [bossp], dados no registro EXT)
spawn_boss:                           ; chamado por spawn com al = ET_BOSS
    pusha
    mov di,enemies
    mov dx,MAXE
.f: cmp byte [di+E_ACT],0
    je .got
    add di,ESZ
    dec dx
    jnz .f
    jmp .x
.got: xor eax,eax
    mov [di],eax
    mov [di+4],eax
    mov [di+8],eax
    mov [di+12],eax
    mov byte [di+E_ACT],1
    mov byte [di+E_TYPE],ET_BOSS
    mov si,[ext]
    mov al,[si+X_BRT]
    mov [di+E_ROUTE],al
    mov ax,[si+X_BHP]
    mov [di+E_HP],ax
    mov [di+E_MAX],ax
    mov al,[si+X_BSPD]
    mov [di+E_SPD],al
    cmp byte [si+X_SHLD],0
    je .ns
    mov byte [di+E_FLAGS],1           ; ZERO-DAY já nasce com escudo
.ns: mov [bossp],di
    mov word [bt],0
    mov byte [bhalf],0
    mov byte [shake],8
    call epos
.x: popa
    ret

boss_armor:                           ; di = chefe, ax = dano -> ax ajustado
    push si
    mov si,[ext]
    test byte [si+X_BFL],BF_ARMOR
    pop si
    jz .x
    push ax                           ; FRAGMENTADOR: dobro sob a cabeça, metade fora
    call ecell
    call quad_of
    cmp al,[quad]
    pop ax
    jne .half
    shl ax,1
    ret
.half: inc ax
    shr ax,1
.x: ret

boss_killed:                          ; di = chefe (dentro do pusha de kill)
    mov si,[ext]
    mov ax,[si+X_BPTS]
    mov cl,1
    call gain
    mov word [bossp],0
    movzx ax,byte [di+E_X]
    add ax,4
    movzx bx,byte [di+E_Y]
    add bx,4
    mov cl,5
    call burst
    mov cl,8
    call burst
    mov cl,12
    call burst
    mov cl,11
    call burst
    mov byte [shake],10
    call sb_reset
    mov si,[ext]
    mov si,[si+X_BN]
    call sb_str
    mov si,s_derrotado
    call sb_str
    mov ax,4605h
    call toast_sb
    mov si,seq_win
    call play_seq
    mov si,[ext]                      ; FRAGMENTADOR se parte em worms
    movzx dx,byte [si+X_SPLIT]
    mov cx,[di+E_D]
    mov bl,[di+E_ROUTE]
.w: test dx,dx
    jz .x
    mov al,3
    call spawn
    sub cx,96
    dec dx
    jmp .w
.x: ret

boss_reached:                         ; di = chefe que chegou ao núcleo -> ax = dano
    push si
    mov word [bossp],0
    mov byte [shake],12
    call sb_reset
    mov si,[ext]
    mov si,[si+X_BN]
    call sb_str
    mov si,s_invadiu
    call sb_str
    mov ax,3C08h
    call toast_sb
    mov si,[ext]
    movzx ax,byte [si+X_BDMG]
    pop si
    ret

bt_every:                             ; cl = período -> ZF=1 quando [bt] é múltiplo
    push ax
    push cx
    push dx
    movzx cx,cl
    test cx,cx
    jz .no
    mov ax,[bt]
    xor dx,dx
    div cx
    test dx,dx
    jmp .x
.no: or cx,1                          ; ZF=0
.x: pop dx
    pop cx
    pop ax
    ret

boss_tick:                            ; habilidades do chefe vivo
    mov di,[bossp]
    test di,di
    jz .r
    cmp byte [di+E_ACT],0
    jne .go
    mov word [bossp],0
.r: ret
.go: pusha
    inc word [bt]
    mov si,[ext]
    ; reforços: bug atrás dele ou vírus em outra pista
    mov cl,[si+X_EVERY]
    call bt_every
    jnz .nc
    movzx cx,byte [si+X_NCALL]
    mov dx,[di+E_D]
.cl: test cx,cx
    jz .cle
    push cx
    mov al,[si+X_CALL]
    cmp al,1
    jne .same
    push ax
    mov al,[active]
    call randbit
    pop ax
    xor cx,cx
    jmp .sp
.same: mov bl,[di+E_ROUTE]
    sub dx,128
    mov cx,dx
.sp: call spawn
    pop cx
    dec cx
    jmp .cl
.cle: call ecell
    mov bl,al
    mov bh,ah
    mov al,2
    mov ah,9
    mov cl,1
    mov dl,4
    call add_fx
.nc: ; vazamento de pontos (MEMORY LEAK)
    mov cl,[si+X_DRAIN]
    call bt_every
    jnz .nd
    cmp word [pontos],0
    je .nd
    dec word [pontos]
.nd: ; calor (MINERADOR)
    test byte [si+X_BFL],BF_HEAT
    jz .nh
    cmp byte [fan],0
    jne .nh
    mov ax,4
    call heat_add
.nh: ; trava torres (CRYPTOLOCKER)
    mov cl,[si+X_LOCK]
    call bt_every
    jnz .nl
    call boss_lock
.nl: ; troca de porta (CRYPTOLOCKER)
    mov cl,[si+X_JUMP]
    call bt_every
    jnz .nj
    call boss_jump
.nj: ; escudo que volta (ZERO-DAY)
    test byte [di+E_FLAGS],1
    jnz .nsh
    mov cl,[si+X_SHLD]
    call bt_every
    jnz .nsh
    or byte [di+E_FLAGS],1
.nsh: ; meia vida: chama ajuda (ZERO-DAY)
    cmp byte [si+X_HALF],255
    je .end
    cmp byte [bhalf],0
    jne .end
    mov ax,[di+E_HP]
    shl ax,1
    cmp ax,[di+E_MAX]
    ja .end
    mov byte [bhalf],1
    movzx cx,byte [si+X_NHALF]
    mov dx,[di+E_D]
    mov bl,[di+E_ROUTE]
    mov al,[si+X_HALF]
.hl: sub dx,160
    push cx
    mov cx,dx
    call spawn
    pop cx
    dec cx
    jnz .hl
    mov si,s_zdroot
    mov ax,3C09h
    call toast
    mov bx,200
    mov cl,4
    call beep
.end: popa
    ret

boss_lock:                            ; trava as 2 torres livres mais perto do chefe di
    pusha
    call ecell
    mov [ex_c],ax
    mov byte [bk_n],0
.round: mov word [bk_best],0
    mov word [bk_bd],0FFFFh
    mov si,[ph]
    movzx cx,byte [si+P_NSLOT]
    mov si,[si+P_SLOTS]
    mov bx,towers
.l: cmp byte [bx+T_TYPE],0
    je .n
    cmp byte [bx+T_LOCK],0
    jne .n
    movzx ax,byte [si]
    movzx dx,byte [ex_c]
    sub ax,dx
    imul ax,ax
    push ax
    movzx ax,byte [si+1]
    movzx dx,byte [ex_c+1]
    sub ax,dx
    imul ax,ax
    pop dx
    add ax,dx
    cmp ax,[bk_bd]
    jae .n
    mov [bk_bd],ax
    mov [bk_best],bx
    mov [bk_sp],si
.n: add si,2
    add bx,TSZ
    dec cx
    jnz .l
    mov bx,[bk_best]
    test bx,bx
    jz .done
    mov byte [bx+T_LOCK],60
    inc byte [bx+T_USE]               ; gasta a célula do soquete
    mov si,[bk_sp]
    mov cl,[si]
    shl cl,3
    add cl,4
    mov ch,[si+1]
    shl ch,3
    add ch,4
    mov bl,[ex_c]
    shl bl,3
    add bl,4
    mov bh,[ex_c+1]
    shl bh,3
    add bh,4
    mov al,1
    mov ah,12
    mov dl,6
    call add_fx
    inc byte [bk_n]
    cmp byte [bk_n],2
    jb .round
.done: cmp byte [bk_n],0
    je .x
    mov si,s_cltrav
    mov ax,2D0Ch
    call toast
    mov bx,200
    mov cl,3
    call beep
.x: popa
    ret

boss_jump:                            ; leva o chefe di para outra porta ativa
    pusha
    mov cl,[di+E_ROUTE]
    mov al,1
    shl al,cl
    not al
    and al,[active]
    and al,0Fh
    jz .x
    call randbit                      ; bl = rota nova
    push bx
    mov bl,[di+E_ROUTE]
    call route_rec
    mov cx,[si+2]                     ; L da rota velha
    pop bx
    mov [di+E_ROUTE],bl
    call route_rec
    mov bx,[si+2]                     ; L da rota nova
    mov ax,[di+E_D]                   ; mesma fração do caminho
    mul bx
    div cx
    sub bx,256
    cmp ax,bx
    jbe .ok
    mov ax,bx
.ok: mov [di+E_D],ax
    mov byte [di+E_FLASH],4
    call epos
    call sb_reset
    mov si,s_saltou
    call sb_str
    mov al,[di+E_ROUTE]
    add al,'A'
    call sb_chr
    mov ax,2D0Ch
    call toast_sb
.x: popa
    ret

wt_spawners:                          ; [P3] grupos da onda soltando inimigos
    mov di,spawners
.sl: mov si,[di]
    test si,si
    jz .sn
    cmp byte [di+2],0
    je .sn
    cmp word [di+4],0
    je .fire
    dec word [di+4]
    jmp .sn
.fire: mov al,[si+3]
    test al,al
    jnz .m
    mov al,0Fh
.m: and al,[active]
    jnz .m2
    mov al,[active]
.m2: mov [sp_mask],al
    mov dl,[si]                       ; tipo
    test byte [flags],F_RAND
    jz .nr
    call randbit
    mov al,dl
    xor cx,cx
    call spawn
    jmp .after
.nr: cmp byte [si+4],1
    jne .np
    xor bl,bl
.all: mov al,[sp_mask]
    mov cl,bl
    shr al,cl
    test al,1
    jz .an
    mov al,dl
    xor cx,cx
    call spawn
.an: inc bl
    cmp bl,4
    jb .all
    jmp .after
.np: cmp byte [si+4],2
    jne .cyc
    call randbit
    mov [sp_r1],bl
    mov al,dl
    xor cx,cx
    call spawn
    mov al,[sp_mask]
    mov cl,[sp_r1]
    mov ah,1
    shl ah,cl
    not ah
    and al,ah
    jz .after
    call randbit
    mov al,dl
    xor cx,cx
    call spawn
    jmp .after
.cyc: mov al,[sp_mask]
    call popcnt4
    mov bl,cl
    mov al,[di+3]
    xor ah,ah
    div bl
    mov cl,ah
    mov al,[sp_mask]
    call nthbit
    mov al,dl
    xor cx,cx
    call spawn
.after: dec byte [di+2]
    inc byte [di+3]
    movzx ax,byte [si+2]
    mov bl,[si+5]
    test bl,bl
    jz .st
    push ax
    mov al,[di+3]
    xor ah,ah
    div bl
    test ah,ah
    pop ax
    jnz .st
    movzx ax,byte [si+6]
.st: mov [di+4],ax
.sn: add di,8
    cmp di,spawners+4*8
    jb .sl
    ret

wt_pipeline:                          ; [P3] pipeline da CPU: distâncias restantes e bolhas
    test byte [flags],F_PIPE
    jz .nopipe
    mov di,enemies
    mov bp,remv
.rv: and byte [di+E_FLAGS],0F7h
    mov word [bp],0FFFFh
    cmp byte [di+E_ACT],0
    je .rvn
    mov bl,[di+E_ROUTE]
    call route_rec
    mov ax,[si+2]
    sub ax,[di+E_D]
    jae .rvp
    xor ax,ax
.rvp: mov [bp],ax
.rvn: add di,ESZ
    add bp,2
    cmp di,enemies+MAXE*ESZ
    jb .rv
    mov byte [pass],8
.pass: mov byte [changed],0
    mov di,enemies
    mov bp,remv
.pe: mov ax,[bp]
    cmp ax,1280
    ja .pen
    test byte [di+E_FLAGS],8
    jnz .pen
    cmp byte [di+E_TYPE],1
    jne .pe2
    cmp byte [di+E_STOP],0
    jne .pen
.pe2: mov si,enemies
    mov bx,remv
.pb: cmp si,di
    je .pbn
    mov dx,[bx]
    cmp dx,1280
    ja .pbn
    test byte [si+E_FLAGS],8
    jnz .blk
    cmp byte [si+E_TYPE],1
    jne .pbn
    cmp byte [si+E_STOP],0
    je .pbn
.blk: mov cx,ax
    sub cx,dx
    jle .pbn
    cmp cx,144
    jae .pbn
    or byte [di+E_FLAGS],8
    mov byte [changed],1
    jmp .pen
.pbn: add si,ESZ
    add bx,2
    cmp si,enemies+MAXE*ESZ
    jb .pb
.pen: add di,ESZ
    add bp,2
    cmp di,enemies+MAXE*ESZ
    jb .pe
    cmp byte [changed],0
    je .nopipe
    dec byte [pass]
    jnz .pass
.nopipe: ret

wt_move:                              ; [P3] movimento dos inimigos -> CF=1 se o núcleo caiu
    mov di,enemies
.mv: cmp byte [di+E_ACT],0
    je .mvn
    cmp byte [di+E_FLASH],0
    je .f0
    dec byte [di+E_FLASH]
.f0: movzx ax,byte [di+E_SPD]
    mov byte [bimm],0
    cmp byte [di+E_TYPE],ET_BOSS
    jne .fb
    mov si,[ext]
    test byte [si+X_BFL],BF_NOSLOW
    jz .fe
    mov byte [bimm],1                 ; ZERO-DAY ignora lentidão
.fe: test byte [si+X_BFL],BF_ENR
    jz .fb
    mov bx,[di+E_HP]
    shl bx,1
    cmp bx,[di+E_MAX]
    ja .fb
    mov bx,ax                         ; furioso: velocidade x1,6
    shr bx,1
    add ax,bx
    shr bx,2
    add ax,bx
.fb: cmp byte [di+E_SLOW],0
    je .s1
    dec byte [di+E_SLOW]
    cmp byte [bimm],0
    jne .s1
    shr ax,1
.s1: cmp byte [ab+1],0
    je .s2
    cmp byte [di+E_TYPE],5
    je .s2
    cmp byte [bimm],0
    jne .s2
    shr ax,1
.s2: cmp byte [di+E_TYPE],2
    jne .s3
    mov bx,[di+E_HP]
    shl bx,1
    cmp bx,[di+E_MAX]
    ja .s3
    shl ax,1
.s3: test ax,ax
    jnz .s4
    inc ax
.s4: mov [mv_s],ax
    mov bl,[di+E_ROUTE]
    call route_rec
    mov cx,[si+2]                     ; L
    test byte [flags],F_PIPE
    jz .nex
    test byte [di+E_FLAGS],2
    jnz .nex
    mov ax,cx
    sub ax,[di+E_D]
    cmp ax,640
    ja .nex
    or byte [di+E_FLAGS],2
    cmp byte [di+E_TYPE],ET_BOSS      ; o chefe não para no EX
    je .nex
    mov byte [di+E_STOP],20
.nex: cmp byte [di+E_STOP],0
    je .ns
    dec byte [di+E_STOP]
    jmp .pos
.ns: test byte [di+E_FLAGS],8
    jnz .pos
    mov ax,[mv_s]
    add [di+E_D],ax
    mov ax,[di+E_D]
    cmp ax,cx
    jb .pos
    ; chegou ao núcleo
    mov byte [di+E_ACT],0
    mov si,[ph]
    movzx bx,byte [di+E_TYPE]
    cmp bl,ET_BOSS
    jne .dn
    call boss_reached                 ; ax = dano do chefe
    jmp .dd
.dn: movzx ax,byte [si+P_EDMG+bx]
.dd: sub [vida],ax
    mov byte [coreflash],8
    mov byte [shake],6
    mov bx,130
    mov cl,4
    call beep
    cmp word [vida],0
    jg .mvn
    mov word [vida],0
    call game_over
    stc                               ; avisa o motor: fim de jogo
    ret
.pos: call epos
    ; ransomware trava a torre mais próxima
    cmp byte [di+E_TYPE],4
    jne .mvn
    test byte [di+E_FLAGS],4
    jnz .mvn
    call ecell
    mov [ex_c],ax
    mov si,[ph]
    movzx cx,byte [si+P_NSLOT]
    mov si,[si+P_SLOTS]
    mov bx,towers
.rl: cmp byte [bx+T_TYPE],0
    je .rn
    mov al,[si]
    sub al,[ex_c]
    jns .ra
    neg al
.ra: cmp al,1
    ja .rn
    mov al,[si+1]
    sub al,[ex_c+1]
    jns .rb
    neg al
.rb: cmp al,1
    ja .rn
    mov byte [bx+T_LOCK],60
    or byte [di+E_FLAGS],4
    test byte [flags],F_WEAR
    jz .rt
    inc byte [bx+T_USE]
.rt: push si
    mov si,s_travada
    mov ax,2D08h
    call toast
    pop si
    jmp .mvn
.rn: add si,2
    add bx,TSZ
    loop .rl
.mvn: add di,ESZ
    cmp di,enemies+MAXE*ESZ
    jb .mv
    clc
    ret

; ---------------------------------------------------------------------
; dados da Pessoa 3
section .data
s_travada:    db 'TORRE TRAVADA',0
s_derrotado:  db ' DERROTADO!',0
s_invadiu:    db ' INVADIU O NUCLEO',0
s_cltrav:     db 'CRYPTOLOCKER TRAVOU TORRES',0
s_saltou:     db 'SALTOU PARA A PORTA ',0
s_zdroot:     db 'ZERO-DAY CHAMOU ROOTKITS',0
