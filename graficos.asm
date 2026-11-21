; =====================================================================
; graficos.asm  ·  PESSOA 1 — GRÁFICOS E TELAS
;
;   - Vídeo VGA (modo 13h reprogramado para 320x120), paleta, retraço e blit
;   - Primitivas: ponto, retângulo, moldura, linha, círculo, sprite, texto
;   - Mapa em tiles (unpack_map), efeitos (burst, add_fx)
;   - Todas as telas: menu, seleção, introdução, HUD, painel, avisos, chefe, fim
;   - Regra do contrato: só LÊ o estado do jogo, nunca altera
;
; Parte do Core Defense x86. Montado junto pelo main.asm:
;   nasm -f bin main.asm -o CORE.COM
; =====================================================================

section .text


; =====================================================================
; vídeo
video_init:
    mov ax,13h
    int 10h
    mov dx,3C4h
    mov ax,0100h                      ; reset síncrono do sequenciador
    out dx,ax
    mov dx,3C2h
    mov al,0E3h                       ; clock 25 MHz, polaridade p/ 480 linhas
    out dx,al
    mov dx,3C4h
    mov ax,0300h
    out dx,ax
    mov dx,3D4h
    mov al,11h
    out dx,al
    inc dx
    in al,dx
    and al,7Fh                        ; desprotege CRTC 0-7
    out dx,al
    dec dx
    mov si,crtc_tab
    mov cx,8
.l: lodsw
    out dx,ax
    loop .l
    ret
crtc_tab: dw 00D06h,03E07h,04309h,0EA10h,0AC11h,0DF12h,0E715h,00616h

set_palette:
    mov dx,3C8h
    xor al,al
    out dx,al
    inc dx
    mov si,pal
    mov cx,17*3
.l: lodsb
    out dx,al
    loop .l
    ret

wait_vsync:
    mov dx,3DAh
    mov cx,0FFFFh
.a: in al,dx
    test al,8
    jz .b0
    loop .a
.b0: mov cx,0FFFFh
.b: in al,dx
    test al,8
    jnz .x
    loop .b
.x: ret

blit:                                 ; back buffer 160x120 -> A000 320x120
    push ds
    push es
    pusha
    mov ax,[bufseg]
    mov ds,ax
    mov ax,0A000h
    mov es,ax
    xor si,si
    xor di,di
    mov cx,W*H/2
.l: lodsw
    mov dl,ah
    mov ah,al
    mov dh,dl
    stosw
    mov ax,dx
    stosw
    loop .l
    popa
    pop es
    pop ds
    ret

; =====================================================================
; primitivas de desenho  (ES = back buffer)
pset:                                 ; cx=x dx=y al=cor (0 = transparente)
    test al,al
    jz .x
    cmp cx,W
    jae .x
    cmp dx,H
    jae .x
    push di
    imul di,dx,W
    add di,cx
    mov [es:di],al
    pop di
.x: ret

fillrect:                             ; ax=x bx=y cx=w dx=h si=cor
    pusha
    add cx,ax
    add dx,bx
    cmp ax,0
    jge .a
    xor ax,ax
.a: cmp cx,W
    jle .b
    mov cx,W
.b: cmp bx,0
    jge .c
    xor bx,bx
.c: cmp dx,H
    jle .d
    mov dx,H
.d: sub cx,ax
    jle .done
    sub dx,bx
    jle .done
    imul di,bx,W
    add di,ax
    mov ax,si
.row: push cx
    push di
    rep stosb
    pop di
    pop cx
    add di,W
    dec dx
    jnz .row
.done: popa
    ret

frame:                                ; ax,bx,cx,dx = x,y,w,h  si=cor
    pusha
    mov [fr_x],ax
    mov [fr_y],bx
    mov [fr_h],dx
    mov dx,1
    call fillrect
    mov bx,[fr_y]
    add bx,[fr_h]
    dec bx
    call fillrect
    mov ax,[fr_x]
    add ax,cx
    dec ax
    push ax
    mov ax,[fr_x]
    mov bx,[fr_y]
    mov cx,1
    mov dx,[fr_h]
    call fillrect
    pop ax
    call fillrect
    popa
    ret

clear_screen:                         ; al = cor
    pusha
    xor di,di
    mov ah,al
    mov cx,W*H/2
    rep stosw
    popa
    ret

drawspr:                              ; si=sprite ax=x bx=y  [spk] [rcmode] [rccol] [rcmap]
    pusha
    mov [sp_x],ax
    mov [sp_y],bx
    lodsb
    mov [sp_w],al
    lodsb
    mov [sp_h],al
    mov byte [sp_j],0
.row: mov byte [sp_i],0
.col: lodsb
    test al,al
    jz .next
    cmp byte [rcmode],1
    jne .m2
    mov al,[rccol]
    jmp .put
.m2: cmp byte [rcmode],2
    jne .put
    mov bx,[rcmap]
    xlat
.put: cmp byte [spk],1
    jne .big
    movzx cx,byte [sp_i]
    add cx,[sp_x]
    movzx dx,byte [sp_j]
    add dx,[sp_y]
    call pset
    jmp .next
.big: push si
    movzx si,al
    movzx cx,byte [spk]
    movzx ax,byte [sp_i]
    imul ax,cx
    add ax,[sp_x]
    movzx bx,byte [sp_j]
    imul bx,cx
    add bx,[sp_y]
    mov dx,cx
    call fillrect
    pop si
.next: inc byte [sp_i]
    mov al,[sp_i]
    cmp al,[sp_w]
    jb .col
    inc byte [sp_j]
    mov al,[sp_j]
    cmp al,[sp_h]
    jb .row
    mov byte [rcmode],0
    mov byte [spk],1
    popa
    ret

drawtext:                             ; si=str ax=x bx=y cl=cor ch=escala -> ax=x final
    push bx
    push cx
    push dx
    push si
    push di
    mov [dt_x],ax
    mov [dt_y],bx
    mov [dt_c],cl
    mov [dt_k],ch
.ch: lodsb
    test al,al
    jz .end
    cmp al,'a'
    jb .u
    cmp al,'z'
    ja .u
    sub al,32
.u: sub al,32
    jb .q
    cmp al,63
    jbe .ok
.q: mov al,'?'-32
.ok: movzx di,al
    imul di,5
    add di,font
    mov byte [dt_r],0
.r: mov bl,[di]
    mov byte [dt_cc],0
.c: test bl,4
    jz .nb
    cmp byte [dt_k],1
    jne .bigp
    movzx cx,byte [dt_cc]
    add cx,[dt_x]
    movzx dx,byte [dt_r]
    add dx,[dt_y]
    mov al,[dt_c]
    call pset
    jmp .nb
.bigp: push si
    push bx
    movzx cx,byte [dt_k]
    movzx ax,byte [dt_cc]
    imul ax,cx
    add ax,[dt_x]
    movzx bx,byte [dt_r]
    imul bx,cx
    add bx,[dt_y]
    mov dx,cx
    movzx si,byte [dt_c]
    call fillrect
    pop bx
    pop si
.nb: shl bl,1
    inc byte [dt_cc]
    cmp byte [dt_cc],3
    jb .c
    inc di
    inc byte [dt_r]
    cmp byte [dt_r],5
    jb .r
    movzx ax,byte [dt_k]
    shl ax,2
    add [dt_x],ax
    jmp .ch
.end: mov ax,[dt_x]
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    ret

textw:                                ; si=str ch=escala -> ax=largura
    push si
    push cx
    xor ax,ax
.l: cmp byte [si],0
    je .e
    inc si
    inc ax
    jmp .l
.e: movzx cx,ch
    shl ax,2
    imul ax,cx
    sub ax,cx
    pop cx
    pop si
    ret

ctext:                                ; si=str bx=y cl=cor ch=esc dx=x0 di=largura da área
    push ax
    call textw
    neg ax
    add ax,di
    sar ax,1
    add ax,dx
    call drawtext
    pop ax
    ret

rtext:                                ; texto alinhado à direita: dx = borda direita
    push ax
    call textw
    neg ax
    add ax,dx
    call drawtext
    pop ax
    ret

line:                                 ; [ln_x0..ln_y1] al=cor
    pusha
    mov [ln_c],al
    mov ax,[ln_x1]
    sub ax,[ln_x0]
    mov si,1
    jge .a
    neg ax
    mov si,-1
.a: mov [ln_dx],ax
    mov [ln_sx],si
    mov ax,[ln_y1]
    sub ax,[ln_y0]
    mov si,1
    jge .b
    neg ax
    mov si,-1
.b: neg ax
    mov [ln_dy],ax
    mov [ln_sy],si
    mov ax,[ln_dx]
    add ax,[ln_dy]
    mov [ln_e],ax
    mov cx,[ln_x0]
    mov dx,[ln_y0]
.lp: mov al,[ln_c]
    call pset
    cmp cx,[ln_x1]
    jne .c
    cmp dx,[ln_y1]
    je .done
.c: mov ax,[ln_e]
    shl ax,1
    cmp ax,[ln_dy]
    jl .d
    mov bx,[ln_dy]
    add [ln_e],bx
    add cx,[ln_sx]
.d: cmp ax,[ln_dx]
    jg .lp
    mov bx,[ln_dx]
    add [ln_e],bx
    add dx,[ln_sy]
    jmp .lp
.done: popa
    ret

circle:                               ; ax=cx bx=cy cl=raio dl=cor
    pusha
    mov [c_x],ax
    mov [c_y],bx
    movzx ax,cl
    mov [c_r],ax
    mov [c_col],dl
    imul ax,ax
    mov [c_rr],ax
    mov si,[c_r]
    neg si
.yl: mov di,[c_r]
    neg di
.xl: mov ax,si
    imul ax,si
    mov bx,di
    imul bx,di
    add ax,bx
    cmp ax,[c_rr]
    jg .n
    mov cx,[c_x]
    add cx,di
    mov dx,[c_y]
    add dx,si
    mov al,[c_col]
    call pset
.n: inc di
    cmp di,[c_r]
    jle .xl
    inc si
    cmp si,[c_r]
    jle .yl
    popa
    ret

unpack_map:                           ; tiles 8x8 -> BUFSEG:BGOFF (160x104)
    pusha
    mov si,[ph]
    mov si,[si+P_MAP]
    mov byte [um_ty],0
.ty: mov byte [um_tx],0
.tx: lodsw
    push si
    shl ax,5
    add ax,tiles
    mov si,ax
    movzx di,byte [um_ty]
    imul di,8*W
    movzx ax,byte [um_tx]
    shl ax,3
    add di,ax
    add di,BGOFF
    mov dx,8
.row: mov cx,4
.px: lodsb
    mov ah,al
    shr al,4
    inc al
    mov [es:di],al
    and ah,0Fh
    inc ah
    mov [es:di+1],ah
    add di,2
    loop .px
    add di,W-8
    dec dx
    jnz .row
    pop si
    inc byte [um_tx]
    cmp byte [um_tx],20
    jb .tx
    inc byte [um_ty]
    cmp byte [um_ty],13
    jb .ty
    popa
    ret

burst:                                ; ax=x bx=y cl=cor: 6 partículas
    pusha
    mov [b_x],ax
    mov [b_y],bx
    mov [b_c],cl
    mov dx,6
    mov di,parts
    mov si,MAXP
.l: test dx,dx
    jz .x
    test si,si
    jz .x
    cmp byte [di],0
    jne .nx
    call rnd
    and al,7
    add al,8
    mov [di],al
    mov al,[b_c]
    test dl,1
    jz .c
    mov al,11
.c: mov [di+1],al
    mov ax,[b_x]
    shl ax,4
    mov [di+2],ax
    mov ax,[b_y]
    shl ax,4
    mov [di+4],ax
    call rnd
    and al,31
    sub al,16
    mov [di+6],al
    call rnd
    and al,31
    sub al,16
    mov [di+7],al
    dec dx
.nx: add di,PSZ
    dec si
    jmp .l
.x: popa
    ret

add_fx:                               ; al=tipo ah=cor bl,bh = x0,y0  cl,ch = x1,y1 (ou r)  dl = vida
    pusha
    mov di,fxs
    mov si,MAXFX
.l: cmp byte [di],0
    je .g
    add di,FXSZ
    dec si
    jnz .l
    jmp .x
.g: mov [di],dl
    mov [di+1],al
    mov [di+2],ah
    mov [di+4],bl
    mov [di+5],bh
    mov [di+6],cl
    mov [di+7],ch
.x: popa
    ret

; =====================================================================
; render
render:
    movzx bx,byte [state]
    shl bx,1
    call [rnd_tab+bx]
    call in_game
    jnc .x
    cmp byte [paused],0
    je .x
    call draw_pause
.x: ret
rnd_tab: dw r_menu,r_ctrl,r_sel,r_intro,r_prep,r_wave,r_aviso,r_wend,r_over,r_win,r_boss

blinkc:                               ; al = cor A se (frame>>bit)&1 senão cor B ; cl = bit, ah = cor B
    push cx
    push dx
    mov dx,[frm]
    shr dx,cl
    test dl,1
    jnz .a
    mov al,ah
.a: pop dx
    pop cx
    ret

r_menu:
    mov al,1
    call clear_screen
    RECT 0,100,160,1,2
    RECT 0,104,160,1,2
    RECT 0,47,72,2,4
    RECT 88,47,72,2,4
    RECT 0,47,72,1,5
    RECT 88,47,72,1,5
    CTEXT s_core,8,6,3,0,160
    CTEXT s_defense,27,11,2,0,160
    SPR spr_cpu,72,40
    mov ax,[frm]
    xor dx,dx
    mov bx,80
    div bx                            ; dx = t
    mov si,spr_bug
    test byte [frm],8
    jz .b1
    mov si,spr_bug2
.b1: mov ax,dx
    sub ax,8
    push dx
    mov bx,44
    call drawspr
    pop dx
    mov si,spr_virus
    test byte [frm],8
    jz .b2
    mov si,spr_virus2
.b2: mov ax,160
    sub ax,dx
    mov bx,44
    call drawspr
    xor bp,bp
.o: mov si,[menu_opts+bp]
    mov bx,bp
    imul bx,5
    add bx,62
    mov cl,11
    movzx ax,byte [menusel]
    shl ax,1
    cmp bp,ax
    jne .on
    mov cl,5
    call sb_reset
    push si
    mov si,s_gt
    call sb_str
    pop si
    call sb_str
    mov si,strbuf
.on: mov ch,1
    mov dx,0
    mov di,160
    call ctext
    add bp,2
    cmp bp,6
    jb .o
    CTEXT s_menu_foot,112,10,1,0,160
    ret
menu_opts: dw s_jogar,s_controles,s_sair

r_ctrl:
    mov al,1
    call clear_screen
    CTEXT s_controles,4,6,2,0,160
    mov bp,ctrl_list
    mov bx,18
.l: mov si,[bp]
    test si,si
    jz .e
    mov ax,8
    mov cl,5
    mov ch,1
    call drawtext
    mov si,[bp+2]
    mov ax,52
    mov cl,11
    call drawtext
    add bp,4
    add bx,8
    jmp .l
.e: CTEXT s_entervolta,112,10,1,0,160
    ret

r_sel:
    mov al,1
    call clear_screen
    CTEXT s_escolha,4,11,1,0,160
    xor bp,bp                         ; i
.c: mov ax,bp
    xor dx,dx
    mov bx,3
    div bx                            ; ax = linha, dx = coluna
    imul dx,51
    add dx,5
    mov [cx_],dx
    imul ax,44
    add ax,14
    mov [cy_],ax
    mov byte [col],10
    mov ax,bp
    cmp al,[selidx]
    jne .ns
    mov byte [col],5
.ns: movzx si,byte [col]
    FRAME [cx_],[cy_],48,40,si
    mov ax,bp
    cmp al,[selidx]
    jne .nd
    mov ax,[cx_]
    inc ax
    mov bx,[cy_]
    inc bx
    mov cx,46
    mov dx,38
    movzx si,byte [col]
    call frame
.nd: mov ax,bp
    add al,'1'
    mov [chbuf],al
    mov byte [chbuf+1],0
    mov ax,[cx_]
    add ax,3
    mov bx,[cy_]
    add bx,3
    mov si,chbuf
    mov cl,[col]
    mov ch,1
    call drawtext
    mov cx,bp
    mov al,1
    shl al,cl
    test [done],al
    jz .nk
    mov ax,[cx_]
    add ax,38
    mov bx,[cy_]
    add bx,3
    mov si,s_ok
    mov cl,16
    mov ch,1
    call drawtext
.nk: mov bx,bp
    shl bx,1
    mov di,[phase_tab+bx]
    mov si,[di+P_ICON]
    mov ax,[cx_]
    add ax,16
    mov bx,[cy_]
    add bx,6
    call drawspr
    mov si,[di+P_NAME]
    mov bx,[cy_]
    add bx,26
    mov cl,11
    mov ch,1
    mov dx,[cx_]
    push di
    mov di,48
    call ctext
    pop di
    call sb_reset
    movzx ax,byte [di+P_NWAV]
    call sb_num
    mov si,s_maischefe
    call sb_str
    mov si,strbuf
    mov bx,[cy_]
    add bx,33
    mov cl,10
    mov ch,1
    mov dx,[cx_]
    mov di,48
    call ctext
    inc bp
    cmp bp,6
    jb .c
    CTEXT s_sel_foot,104,11,1,0,160
    CTEXT s_qvolta,112,10,1,0,160
    ret

r_intro:
    cmp byte [intropg],0
    je .p1
    jmp r_intro2
.p1: mov al,1
    call clear_screen
    call sb_reset
    mov si,s_fase_sp
    call sb_str
    movzx ax,byte [phidx]
    inc ax
    call sb_num
    mov si,s_de6
    call sb_str
    TEXT strbuf,6,6,6,1
    mov di,[ph]
    mov si,[di+P_TITLE]
    mov ax,6
    mov bx,14
    mov cl,11
    mov ch,2
    call drawtext
    mov ch,2
    call textw
    mov cx,ax
    movzx si,byte [di+P_BAND]
    mov ax,6
    mov bx,27
    mov dx,2
    call fillrect
    RECT 6,36,52,52,15
    mov byte [spk],3
    mov si,[di+P_ICON]
    mov ax,8
    mov bx,38
    call drawspr
    xor bp,bp
.i: mov si,[di+P_INTRO+bp]
    mov bx,bp
    shr bx,1
    imul bx,9
    add bx,40
    mov ax,66
    mov cl,11
    mov ch,1
    call drawtext
    add bp,2
    cmp bp,6
    jb .i
    RECT 6,86,148,1,10
    xor bp,bp
.r: mov bx,bp
    shr bx,1
    imul bx,7
    add bx,91
    mov si,s_gtc
    mov ax,6
    mov cl,5
    mov ch,1
    call drawtext
    mov si,[di+P_REGRA+bp]
    mov ax,14
    mov cl,11
    test bp,bp
    jnz .rc
    mov cl,5
.rc: call drawtext
    add bp,2
    cmp bp,6
    jb .r
    test byte [frm],8
    jz .x
    CTEXT s_entercomeca,113,10,1,0,160
.x: ret

; ---- mundo ----
draw_bg:
    pusha
    push ds
    xor di,di
    mov ax,0101h
    mov cx,8*W/2
    rep stosw
    mov di,112*W
    mov cx,8*W/2
    rep stosw
    mov ax,es
    mov ds,ax
    mov si,BGOFF
    mov di,8*W
    mov cx,104*W/2
    rep movsw
    pop ds
    popa
    ret

slot_frame:                           ; ax = x, bx = y (px), dl = cor
    pusha
    mov [sf_x],ax
    mov [sf_y],bx
    mov [sf_c],dl
    mov si,1
.l: mov cx,[sf_x]
    add cx,si
    mov dx,[sf_y]
    mov al,[sf_c]
    call pset
    add dx,7
    call pset
    mov cx,[sf_x]
    mov dx,[sf_y]
    add dx,si
    call pset
    add cx,7
    call pset
    inc si
    cmp si,7
    jb .l
    popa
    ret

draw_world:
    call draw_bg
    mov di,[ph]
    ; portas
    movzx cx,byte [di+P_NROUT]
    xor bl,bl
.pr: push cx
    call route_rec
    movzx ax,byte [si+4]
    shl ax,3
    movzx dx,byte [si+5]
    shl dx,3
    mov [pp_x],ax
    mov [pp_y],dx
    mov cl,bl
    mov al,1
    shl al,cl
    mov [pp_bit],al
    mov byte [pp_blink],0
    cmp byte [state],ST_AVISO
    jne .pb
    test [di+P_OPENM],al
    jz .pb
    test byte [frm],4
    jz .pb
    mov byte [pp_blink],1
.pb: mov si,spr_porta_off
    mov al,[pp_bit]
    test [active],al
    jz .pd
    cmp byte [pp_blink],0
    jne .pd
    mov si,spr_porta_on
.pd: mov ax,[pp_x]
    push bx
    mov bx,[pp_y]
    call drawspr
    pop bx
    cmp byte [pp_blink],0
    je .pn
    push bx
    mov ax,[pp_x]
    dec ax
    mov bx,[pp_y]
    dec bx
    mov cx,10
    mov dx,10
    mov si,8
    call frame
    pop bx
.pn: inc bl
    pop cx
    dec cx
    jnz .pr
    ; soquetes e torres
    movzx cx,byte [di+P_NSLOT]
    mov si,[di+P_SLOTS]
    mov bp,towers
.sl: push cx
    push si
    movzx ax,byte [si]
    shl ax,3
    mov [sx_],ax
    movzx bx,byte [si+1]
    shl bx,3
    mov [sy_],bx
    mov al,[si]
    mov ah,[si+1]
    mov [sc_],ax
    cmp byte [bp+T_TYPE],0
    je .empty
    movzx bx,byte [bp+T_TYPE]
    shl bx,1
    mov si,[tower_spr+bx]
    cmp byte [bp+T_LOCK],0
    je .tok
    mov byte [rcmode],1
    mov byte [rccol],10
    mov ax,[sx_]
    mov bx,[sy_]
    call drawspr
    mov ax,[sx_]
    mov bx,[sy_]
    sub bx,7
    mov si,spr_cadeado
    call drawspr
    jmp .snext
.tok: cmp byte [bp+T_FLASH],0
    je .tf
    mov byte [rcmode],2
    mov word [rcmap],map_flash7
.tf: mov ax,[sx_]
    mov bx,[sy_]
    call drawspr
    cmp byte [bp+T_LVL],2
    jb .snext
    mov ax,[sx_]
    add ax,6
    mov bx,[sy_]
    mov cx,2
    mov dx,2
    mov si,5
    call fillrect
    jmp .snext
.empty: test byte [di+P_FLAGS],F_WEAR
    jz .nw
    cmp byte [bp+T_USE],2
    jb .nw
    mov ax,[sx_]
    inc ax
    mov bx,[sy_]
    inc bx
    mov cx,6
    mov dx,6
    mov si,1
    call fillrect
    mov ax,[sx_]
    inc ax
    mov [ln_x0],ax
    add ax,5
    mov [ln_x1],ax
    mov ax,[sy_]
    inc ax
    mov [ln_y0],ax
    add ax,5
    mov [ln_y1],ax
    mov al,10
    call line
    mov ax,[ln_x0]
    xchg ax,[ln_x1]
    mov [ln_x0],ax
    mov al,10
    call line
    mov ax,[sx_]
    mov bx,[sy_]
    mov dl,10
    call slot_frame
    jmp .snext
.nw: mov dl,5
    test byte [di+P_FLAGS],F_HEAD
    jz .sf
    mov ax,[sc_]
    call quad_of
    cmp al,[quad]
    jne .sf
    mov dl,6
.sf: mov ax,[sx_]
    mov bx,[sy_]
    call slot_frame
    test byte [di+P_FLAGS],F_WEAR
    jz .snext
    cmp byte [bp+T_USE],1
    jne .snext
    mov ax,[sx_]
    add ax,3
    mov bx,[sy_]
    add bx,3
    mov cx,2
    mov dx,2
    mov si,12
    call fillrect
.snext: pop si
    add si,2
    add bp,TSZ
    pop cx
    dec cx
    jnz .sl
    ; núcleo
    cmp byte [coreflash],0
    je .cn
    test byte [frm],1
    jz .cn
    mov byte [rcmode],2
    mov word [rcmap],map_coreflash
.cn: mov si,[di+P_CSPR]
    movzx ax,byte [di+P_COREX]
    shl ax,3
    movzx bx,byte [di+P_COREY]
    shl bx,3
    call drawspr
    call draw_el                      ; elemento do mapa
    ; inimigos
    mov bp,enemies
.el: cmp byte [bp+E_ACT],0
    je .en
    cmp byte [bp+E_TYPE],ET_BOSS
    jne .enb
    call draw_boss_e
    jmp .en
.enb: movzx bx,byte [bp+E_TYPE]
    shl bx,2
    test byte [frm],8
    jz .ef
    add bx,2
.ef: mov si,[enemy_spr+bx]
    cmp byte [bp+E_TYPE],2
    jne .eg
    mov ax,[bp+E_HP]
    shl ax,1
    cmp ax,[bp+E_MAX]
    ja .eg
    mov si,spr_trojan_f
.eg: cmp byte [bp+E_FLASH],0
    je .eh
    mov byte [rcmode],1
    mov byte [rccol],11
    jmp .ed
.eh: cmp byte [bp+E_TYPE],5
    jne .ed
    test byte [bp+E_FLAGS],1
    jnz .ed
    mov byte [rcmode],2
    mov word [rcmap],map_rootkit
.ed: movzx ax,byte [bp+E_X]
    movzx bx,byte [bp+E_Y]
    call drawspr
    ; barra de vida
    mov ax,[bp+E_HP]
    cmp ax,[bp+E_MAX]
    jae .eslow
    cmp word [bp+E_MAX],1
    jbe .eslow
    mov cx,6
    mov ax,1
    cmp byte [bp+E_TYPE],2
    jne .ew
    mov cx,10
    mov ax,-1
.ew: mov [hb_w],cx
    movzx dx,byte [bp+E_X]
    add ax,dx
    mov [hb_x],ax
    movzx bx,byte [bp+E_Y]
    sub bx,2
    mov [hb_y],bx
    mov dx,1
    mov si,2
    call fillrect
    mov ax,[bp+E_HP]
    imul ax,[hb_w]
    xor dx,dx
    div word [bp+E_MAX]
    test ax,ax
    jnz .ew2
    inc ax
.ew2: mov cx,ax
    mov si,8
    mov ax,[bp+E_HP]
    shl ax,1
    cmp ax,[bp+E_MAX]
    jbe .ew3
    mov si,16
.ew3: mov ax,[hb_x]
    mov bx,[hb_y]
    mov dx,1
    call fillrect
.eslow: cmp byte [bp+E_SLOW],0
    je .est
    movzx cx,byte [bp+E_X]
    add cx,3
    movzx dx,byte [bp+E_Y]
    sub dx,3
    mov al,6
    call pset
    inc cx
    call pset
.est: cmp byte [bp+E_STOP],0
    jne .stp
    test byte [bp+E_FLAGS],8
    jz .en
.stp: movzx cx,byte [bp+E_X]
    add cx,7
    movzx dx,byte [bp+E_Y]
    dec dx
    mov al,12
    call pset
.en: add bp,ESZ
    cmp bp,enemies+MAXE*ESZ
    jb .el
    ; efeitos
    mov bp,fxs
.fl: cmp byte [bp],0
    je .fn
    cmp byte [bp+1],1
    jne .f2
    movzx ax,byte [bp+4]
    mov [ln_x0],ax
    movzx ax,byte [bp+5]
    mov [ln_y0],ax
    movzx ax,byte [bp+6]
    mov [ln_x1],ax
    movzx ax,byte [bp+7]
    mov [ln_y1],ax
    mov al,[bp+2]
    call line
    jmp .fn
.f2: cmp byte [bp+1],2
    jne .f3
    movzx cx,byte [bp+6]              ; r
    movzx ax,byte [bp+4]
    sub ax,cx
    shl ax,3
    movzx bx,byte [bp+5]
    sub bx,cx
    shl bx,3
    cmp bx,8
    jge .f2b
    mov bx,8
.f2b: shl cx,1
    inc cx
    shl cx,3
    mov dx,cx
    mov si,9
    test byte [bp],1
    jz .f2c
    mov si,11
.f2c: call frame
    jmp .fn
.f3: movzx ax,byte [bp+4]
    shl ax,3
    movzx bx,byte [bp+5]
    shl bx,3
    mov byte [rcmode],1
    mov byte [rccol],5
    mov si,spr_mira
    call drawspr
    add ax,3
    add bx,3
    mov cx,2
    mov dx,2
    mov si,11
    call fillrect
.fn: add bp,FXSZ
    cmp bp,fxs+MAXFX*FXSZ
    jb .fl
    ; partículas
    mov bp,parts
.ptl: cmp byte [bp],0
    je .ptn
    mov cx,[bp+2]
    sar cx,4
    mov dx,[bp+4]
    sar dx,4
    mov al,[bp+1]
    call pset
.ptn: add bp,PSZ
    cmp bp,parts+MAXP*PSZ
    jb .ptl
    ; cabeça de leitura do HD
    test byte [di+P_FLAGS],F_HEAD
    jz .nhd
    mov ax,150
    mov bx,18
    mov cl,6
    mov dl,15
    call circle
    mov cl,3
    mov dl,14
    call circle
    movzx bx,byte [quad]
    shl bx,2
    mov ax,[hd_q+bx]
    mov dx,[hd_q+bx+2]
    mov [hq_x],ax
    mov [hq_y],dx
    mov word [ln_x0],148
    mov word [ln_y0],20
    mov [ln_x1],ax
    mov [ln_y1],dx
    mov al,10
    call line
    mov word [ln_x0],149
    mov word [ln_y0],21
    inc word [ln_x1]
    inc word [ln_y1]
    call line
    mov ax,[hq_x]
    sub ax,2
    mov bx,[hq_y]
    sub bx,2
    mov cx,4
    mov dx,4
    mov si,5
    cmp byte [seekh],0
    je .hh
    mov si,6                          ; cabeça presa pela busca
.hh: call fillrect
    cmp byte [seekh],0
    je .nhd
    mov ax,[hq_x]
    sub ax,4
    mov bx,[hq_y]
    sub bx,4
    mov cx,8
    mov dx,8
    mov si,6
    test byte [frm],4
    jz .hf
    mov si,11
.hf: call frame
.nhd: call draw_bossbar
    cmp byte [flashall],0
    je .x
    mov bx,8
.fa: xor ax,ax
    mov cx,160
    mov dx,1
    mov si,6
    call fillrect
    add bx,2
    cmp bx,112
    jb .fa
.x: ret
hd_q: dw 88,40, 88,88, 40,88, 40,40

hud_top:
    RECT 0,0,160,8,1
    SPR spr_vida,1,0
    RECT 11,2,20,4,2
    mov cx,[vida]
    RECT 11,2,cx,4,8
    mov ax,[vida]
    call itoa
    mov ax,34
    mov bx,2
    mov cl,11
    mov ch,1
    call drawtext
    SPR spr_ponto,48,0
    mov ax,[pontos]
    call itoa
    mov ax,58
    mov bx,2
    mov cl,5
    mov ch,1
    call drawtext
    mov di,[ph]
    test byte [di+P_FLAGS],F_CAP
    jz .nc
    mov dx,[di+P_CAP]
    cmp [pontos],dx
    jb .nc
    add ax,2
    mov si,s_max
    mov cl,8
    call drawtext
.nc: test byte [di+P_FLAGS],F_HEAT
    jz .nh
    TEXT s_t,86,2,12,1
    RECT 91,2,20,4,2
    mov ax,[heat]
    xor dx,dx
    mov cx,50
    div cx
    mov cx,ax
    mov si,12
    cmp byte [hot],0
    je .hc
    mov si,11
    test byte [frm],2
    jz .hc
    mov si,8
.hc: mov ax,91
    mov bx,2
    mov dx,4
    call fillrect
.nh: cmp byte [fast],0
    je .nf
    TEXT s_2x,114,2,6,1
.nf: mov al,[wave]
    cmp al,[di+P_NWAV]
    jbe .on
    mov al,8                          ; onda do chefe
    mov ah,12
    mov cl,3
    call blinkc
    mov cl,al
    mov si,s_chefe
    mov dx,160
    mov bx,2
    mov ch,1
    call rtext
    ret
.on: call sb_reset
    mov si,s_onda_sp
    call sb_str
    movzx ax,byte [wave]
    call sb_num
    mov al,'/'
    call sb_chr
    movzx ax,byte [di+P_NWAV]
    inc ax
    call sb_num
    mov si,strbuf
    mov dx,160
    mov bx,2
    mov cl,11
    mov ch,1
    call rtext
    ret

hud_bottom:
    RECT 0,112,160,8,1
    TEXT s_reg,1,114,10,1
    xor bp,bp
.am: mov ax,bp
    imul ax,3
    add ax,14
    mov si,2
    mov cx,bp
    cmp cl,[ammo]
    jae .ac
    mov si,6
    cmp byte [shotlock],0
    je .ac
    mov si,10
.ac: mov bx,114
    mov cx,2
    mov dx,5
    call fillrect
    inc bp
    cmp bp,12
    jb .am
    mov di,[ph]
    xor bp,bp
.ab: mov ax,bp
    imul ax,26
    add ax,56
    mov [ab_x],ax
    mov ax,bp
    add al,'1'
    mov [chbuf],al
    mov byte [chbuf+1],0
    mov al,[di+P_ABIL]
    mov cx,bp
    shr al,cl
    test al,1
    jnz .ok
    mov si,spr_cadeado
    mov ax,[ab_x]
    mov bx,112
    call drawspr
    mov cl,10
    jmp .num
.ok: mov bx,bp
    shl bx,1
    mov si,[ab_spr+bx]
    cmp byte [ab+bp],0
    je .na
    mov ax,[ab_x]
    mov bx,112
    call drawspr
    movzx ax,byte [ab+bp]
    add ax,17
    xor dx,dx
    mov cx,18
    div cx
    call sb_reset
    call sb_num
    mov al,'S'
    call sb_chr
    mov si,strbuf
    mov ax,[ab_x]
    add ax,10
    mov bx,114
    mov cl,5
    mov ch,1
    call drawtext
    jmp .nx
.na: mov bx,bp
    shl bx,1
    mov ax,[ab_cost+bx]
    cmp [pontos],ax
    jae .rich
    mov byte [rcmode],1
    mov byte [rccol],10
    mov ax,[ab_x]
    mov bx,112
    call drawspr
    mov cl,10
    jmp .num
.rich: mov ax,[ab_x]
    mov bx,112
    call drawspr
    mov cl,11
.num: mov si,chbuf
    mov ax,[ab_x]
    add ax,10
    mov bx,114
    mov ch,1
    call drawtext
.nx: inc bp
    cmp bp,4
    jb .ab
    ret

draw_panel:
    RECT 128,8,32,104,1
    FRAME 128,8,32,104,10
    CTEXT s_torres,11,6,1,128,32
    mov di,[ph]
    xor bp,bp
.l: mov ax,bp
    movzx cx,byte [di+P_NTOW]
    cmp ax,cx
    jae .e
    imul ax,15
    add ax,20
    mov [pn_y],ax
    mov al,[di+P_TOWT+bp]
    mov [pn_t],al
    call unlocked
    setc [pn_ok]
    mov al,[pn_t]
    cmp al,[sel]
    jne .ns
    mov bx,[pn_y]
    sub bx,2
    FRAME 130,bx,28,12,5
.ns: mov ax,bp
    add al,'1'
    mov [chbuf],al
    mov byte [chbuf+1],0
    mov cl,10
    cmp byte [pn_ok],0
    je .c1
    mov cl,11
.c1: mov si,chbuf
    mov ax,132
    mov bx,[pn_y]
    add bx,2
    mov ch,1
    call drawtext
    mov si,spr_cadeado
    cmp byte [pn_ok],0
    je .sp
    movzx bx,byte [pn_t]
    shl bx,1
    mov si,[tower_spr+bx]
.sp: mov ax,137
    mov bx,[pn_y]
    call drawspr
    movzx bx,byte [pn_t]
    shl bx,3
    mov ax,[tower_tab+bx]
    mov cl,10
    cmp byte [pn_ok],0
    je .cc
    mov cl,8
    cmp [pontos],ax
    jb .cc
    mov cl,5
.cc: call itoa
    mov ax,146
    mov bx,[pn_y]
    add bx,2
    mov ch,1
    call drawtext
    inc bp
    jmp .l
.e: RECT 131,82,26,1,10
    CTEXT s_tempo,85,10,1,128,32
    mov ax,[prept]
    add ax,17
    xor dx,dx
    mov cx,18
    div cx
    call itoa
    CTEXT si,92,11,1,128,32
    mov al,6
    mov ah,11
    mov cl,3
    call blinkc
    CTEXT s_enter,101,al,1,128,32
    ret

draw_range:                           ; alcance da torre escolhida em volta do cursor
    movzx bx,byte [sel]
    shl bx,3
    movzx cx,byte [tower_tab+bx+3]
    movzx ax,byte [cursx]
    sub ax,cx
    shl ax,3
    mov [rg_x],ax
    movzx ax,byte [cursy]
    sub ax,cx
    shl ax,3
    mov [rg_y],ax
    shl cx,1
    inc cx
    shl cx,3
    mov [rg_w],cx
    xor si,si
.l: mov cx,[rg_x]
    add cx,si
    mov dx,[rg_y]
    call rg_dot
    add dx,[rg_w]
    dec dx
    call rg_dot
    mov cx,[rg_x]
    mov dx,[rg_y]
    add dx,si
    call rg_dot
    add cx,[rg_w]
    dec cx
    call rg_dot
    add si,2
    cmp si,[rg_w]
    jb .l
    ret
rg_dot: cmp dx,8
    jl .x
    cmp dx,112
    jge .x
    cmp cx,128
    jge .x
    mov al,6
    call pset
.x: ret

draw_toast:
    cmp byte [toast_l],0
    je .x
    mov si,toastbuf
    mov ch,1
    call textw
    add ax,8
    mov [ts_w],ax
    mov bx,160
    cmp byte [state],ST_PREP
    jne .a
    mov bx,128
.a: sub bx,ax
    sar bx,1
    mov [ts_x],bx
    movzx si,byte [toast_c]
    mov ax,[ts_x]
    mov bx,99
    mov cx,[ts_w]
    mov dx,9
    push si
    mov si,1
    call fillrect
    pop si
    call frame
    mov si,toastbuf
    mov ax,[ts_x]
    add ax,4
    mov bx,101
    mov cl,[toast_c]
    mov ch,1
    call drawtext
.x: ret

caixa:                                ; ax,bx,cx,dx = x,y,w,h  si = cor da borda
    pusha
    push si
    mov si,1
    call fillrect
    pop si
    call frame
    add ax,2
    add bx,2
    sub cx,4
    sub dx,4
    mov si,2
    call frame
    popa
    ret

r_prep:
    call draw_world
    mov al,[sel]
    call unlocked
    jnc .nr
    call draw_range
.nr: mov al,11
    mov ah,5
    mov cl,2
    call blinkc
    mov byte [rcmode],1
    mov [rccol],al
    movzx ax,byte [cursx]
    shl ax,3
    movzx bx,byte [cursy]
    shl bx,3
    mov si,spr_cursor
    call drawspr
    call hud_top
    call hud_bottom
    call draw_panel
    call draw_toast
    ret
r_wave:
    call draw_world
    cmp byte [shotlock],0
    jne .g
    cmp byte [ammo],0
    jne .d
.g: mov byte [rcmode],1
    mov byte [rccol],10
.d: movzx ax,byte [mirax]
    shl ax,3
    movzx bx,byte [miray]
    shl bx,3
    mov si,spr_mira
    call drawspr
    call hud_top
    call hud_bottom
    call draw_toast
    ret
r_aviso:
    call draw_world
    call hud_top
    call hud_bottom
    mov al,8
    mov ah,10
    mov cl,2
    call blinkc
    movzx si,al
    mov [col],al
    mov ax,26
    mov bx,46
    mov cx,108
    mov dx,30
    call caixa
    CTEXT s_novaentrada,51,[col],1,0,160
    mov di,[ph]
    mov si,[di+P_OMSG]
    CTEXT si,63,11,1,0,160
    ret
r_wend:
    call draw_world
    call hud_top
    call hud_bottom
    mov ax,24
    mov bx,28
    mov cx,112
    mov dx,64
    mov si,5
    call caixa
    call sb_reset
    mov di,[ph]
    mov al,[wave]
    cmp al,[di+P_NWAV]
    jbe .wl
    mov si,s_chefevenc
    call sb_str
    jmp .wt
.wl: mov si,s_onda_sp
    call sb_str
    movzx ax,byte [wave]
    call sb_num
    mov si,s_limpa
    call sb_str
.wt: CTEXT strbuf,34,5,1,0,160
    TEXT s_inimigos,34,46,11,1
    call sb_reset
    mov al,'+'
    call sb_chr
    mov ax,[wavegain]
    call sb_num
    mov si,strbuf
    mov dx,127
    mov bx,46
    mov cl,11
    call rtext
    TEXT s_bonus,34,54,11,1
    call sb_reset
    mov al,'+'
    call sb_chr
    mov ax,[bonus]
    call sb_num
    mov si,strbuf
    mov dx,127
    mov bx,54
    mov cl,5
    call rtext
    RECT 34,61,92,1,10
    TEXT s_pontos,34,64,11,1
    mov ax,[pontos]
    call itoa
    mov dx,127
    mov bx,64
    mov cl,5
    mov ch,1
    call rtext
    cmp byte [newtower],0
    je .nt
    call sb_reset
    mov si,s_novatorre
    call sb_str
    movzx bx,byte [newtower]
    shl bx,1
    mov si,[tower_name+bx]
    call sb_str
    CTEXT strbuf,73,6,1,0,160
.nt: test byte [frm],8
    jz .x
    mov si,s_entercont
    mov di,[ph]
    mov al,[wave]
    cmp al,[di+P_NWAV]
    jbe .t
    mov si,s_enterfin
.t: CTEXT si,82,10,1,0,160
.x: ret
r_over:
    mov al,1
    call clear_screen
    xor bx,bx
.l: xor ax,ax
    mov cx,160
    mov dx,1
    mov si,2
    call fillrect
    add bx,4
    cmp bx,120
    jb .l
    RECT 0,6,160,38,1
    CTEXT s_kernel,8,8,3,0,160
    CTEXT s_panic,26,8,3,0,160
    RECT 0,48,160,52,1
    mov byte [spk],2
    SPR spr_cpu_dano,64,50
    CTEXT s_nucleo,86,11,1,0,160
    RECT 0,96,160,24,1
    call sb_reset
    mov di,[ph]
    mov si,[di+P_NAME]
    call sb_str
    mov al,[wave]
    cmp al,[di+P_NWAV]
    jbe .ow
    mov si,s_sp_chefe
    call sb_str
    jmp .ot
.ow: mov si,s_onda_sp2
    call sb_str
    movzx ax,byte [wave]
    call sb_num
    mov al,'/'
    call sb_chr
    movzx ax,byte [di+P_NWAV]
    inc ax
    call sb_num
.ot: TEXT strbuf,6,98,10,1
    call sb_reset
    mov si,s_pontos_sp2
    call sb_str
    mov ax,[pontos]
    call sb_num
    mov si,strbuf
    mov dx,155
    mov bx,98
    mov cl,5
    mov ch,1
    call rtext
    mov ax,[pontos]
    call hex4
    mov dx,155
    mov bx,106
    mov cl,6
    call rtext
    test byte [frm],8
    jz .x
    CTEXT s_entervolta,113,11,1,0,160
.x: ret
r_win:
    mov al,1
    call clear_screen
    RECT 0,47,64,2,4
    RECT 96,47,64,2,4
    RECT 0,47,64,1,5
    RECT 96,47,64,1,5
    CTEXT s_sistema,6,11,2,0,160
    CTEXT s_limpo,20,6,3,0,160
    mov byte [spk],2
    mov di,[ph]
    mov si,[di+P_CSPR]
    mov ax,64
    mov bx,40
    call drawspr
    call sb_reset
    mov si,s_fase_sp
    call sb_str
    movzx ax,byte [phidx]
    inc ax
    call sb_num
    mov si,s_traco
    call sb_str
    mov si,[di+P_NAME]
    call sb_str
    CTEXT strbuf,78,5,1,0,160
    TEXT s_vida,30,88,10,1
    call sb_reset
    mov ax,[vida]
    call sb_num
    mov si,s_de20
    call sb_str
    mov si,strbuf
    mov dx,131
    mov bx,88
    mov cl,11
    mov ch,1
    call rtext
    TEXT s_pontos,30,96,10,1
    mov ax,[pontos]
    call itoa
    mov dx,131
    mov bx,96
    mov cl,5
    mov ch,1
    call rtext
    test byte [frm],8
    jz .x
    CTEXT s_entercont,112,11,1,0,160
.x: ret
; ---- telas e desenho do chefe e do elemento do mapa ----
r_intro2:                             ; página 2 da introdução: elemento e chefe
    mov al,1
    call clear_screen
    TEXT s_elemmapa,6,5,6,1
    mov di,[ext]
    mov si,[di+X_ELN]
    mov ax,6
    mov bx,13
    mov cl,5
    mov ch,2
    call drawtext
    xor bp,bp
.t: mov si,[di+X_TXT+bp]
    mov bx,bp
    shl bx,2
    add bx,28
    mov ax,6
    mov cl,11
    mov ch,1
    call drawtext
    add bp,2
    cmp bp,6
    jb .t
    RECT 6,53,148,1,10
    TEXT s_chefefinal,6,57,8,1
    RECT 6,65,34,34,2
    mov di,[ext]
    mov byte [spk],2
    mov si,[di+X_BSPR]
    test byte [frm],8
    jz .s1
    mov si,[di+X_BSPR2]
.s1: mov ax,7
    mov bx,66
    call drawspr
    mov si,[di+X_BN]
    mov ax,46
    mov bx,66
    mov cl,11
    mov ch,2
    call drawtext
    xor bp,bp
.d: mov si,[di+X_BD+bp]
    mov bx,bp
    shl bx,2
    add bx,80
    mov ax,46
    mov cl,11
    cmp bp,4
    jne .dc
    mov cl,5
.dc: mov ch,1
    call drawtext
    add bp,2
    cmp bp,6
    jb .d
    test byte [frm],8
    jz .x
    CTEXT s_entercomeca,113,10,1,0,160
.x: ret

r_boss:                               ; alerta antes da onda do chefe
    call draw_world
    call hud_top
    call hud_bottom
    mov al,8
    mov ah,12
    mov cl,2
    call blinkc
    mov [col],al
    movzx si,al
    mov ax,8
    mov bx,18
    mov cx,144
    mov dx,84
    call caixa
    CTEXT s_alerta,24,[col],1,0,160
    mov di,[ext]
    mov byte [spk],2
    mov si,[di+X_BSPR]
    test byte [frm],8
    jz .s1
    mov si,[di+X_BSPR2]
.s1: mov ax,64
    mov bx,31
    call drawspr
    mov di,[ext]
    mov si,[di+X_BN]
    CTEXT si,64,11,1,0,160
    xor bp,bp
.d: mov di,[ext]
    mov si,[di+X_BD+bp]
    mov bx,bp
    shr bx,1
    imul bx,7
    add bx,72
    mov cl,10
    mov ch,1
    xor dx,dx
    mov di,160
    call ctext
    add bp,2
    cmp bp,6
    jb .d
    test byte [frm],8
    jz .x
    CTEXT s_enterprep,93,5,1,0,160
.x: ret

draw_boss_e:                          ; bp = chefe
    pusha
    mov di,[ext]
    mov si,[di+X_BSPR]
    test byte [frm],8
    jz .a
    mov si,[di+X_BSPR2]
.a: movzx ax,byte [bp+E_X]
    sub ax,4
    movzx bx,byte [bp+E_Y]
    sub bx,4
    test byte [frm],4
    jz .b
    dec bx
.b: cmp byte [bp+E_FLASH],0
    je .c
    mov byte [rcmode],1
    mov byte [rccol],11
.c: mov [bb_x],ax
    mov [bb_y],bx
    call drawspr
    test byte [bp+E_FLAGS],1          ; escudo
    jz .st
    mov ax,[bb_x]
    dec ax
    mov bx,[bb_y]
    dec bx
    mov cx,18
    mov dx,18
    mov si,6
    call frame
.st: cmp byte [bp+E_STOP],0
    jne .sp
    test byte [bp+E_FLAGS],8
    jz .x
.sp: mov cx,[bb_x]
    add cx,15
    mov dx,[bb_y]
    dec dx
    mov al,12
    call pset
.x: popa
    ret

draw_bossbar:                         ; barra de vida do chefe no alto do mapa
    pusha
    mov di,[bossp]
    test di,di
    jz .x
    cmp byte [di+E_ACT],0
    je .x
    RECT 8,9,112,8,1
    FRAME 8,9,112,8,8
    mov si,[ext]
    mov si,[si+X_BN]
    mov ax,11
    mov bx,11
    mov cl,11
    mov ch,1
    call drawtext
    add ax,2
    mov [bb_x],ax
    mov cx,116
    sub cx,ax
    mov [bb_w],cx
    mov bx,12
    mov dx,3
    mov si,2
    call fillrect
    mov ax,[di+E_HP]
    test ax,ax
    jle .x
    mul word [bb_w]
    div word [di+E_MAX]
    test ax,ax
    jnz .w
    inc ax
.w: mov cx,ax
    mov si,8
    test byte [di+E_FLAGS],1
    jz .c
    mov si,10
.c: mov ax,[bb_x]
    mov bx,12
    mov dx,3
    call fillrect
.x: popa
    ret

box_frame:                            ; si = caixa em tiles -> moldura dupla piscando
    pusha
    cmp byte [si],255
    je .x
    movzx ax,byte [si]
    movzx cx,byte [si+2]
    sub cx,ax
    inc cx
    shl cx,3
    shl ax,3
    movzx bx,byte [si+1]
    movzx dx,byte [si+3]
    sub dx,bx
    inc dx
    shl dx,3
    shl bx,3
    mov si,5
    call frame
    inc ax
    inc bx
    sub cx,2
    sub dx,2
    mov si,11
    call frame
.x: popa
    ret

draw_el:                              ; elemento do mapa da fase atual
    pusha
    mov di,[ext]
    cmp word [di+X_KEYS],0
    je .box
    cmp byte [el_on],0                ; teclado: tecla acesa com "D"
    je .x
    movzx ax,byte [el_kx]
    shl ax,3
    mov [bb_x],ax
    movzx bx,byte [el_ky]
    shl bx,3
    mov [bb_y],bx
    mov si,5
    cmp byte [el_life],25
    jae .k1
    test byte [frm],2
    jz .k1
    mov si,8
.k1: mov [bb_c],si
    inc ax
    inc bx
    mov cx,6
    mov dx,6
    call fillrect
    mov dx,1
    mov si,11
    call fillrect
    mov si,s_D
    mov ax,[bb_x]
    add ax,2
    mov bx,[bb_y]
    add bx,2
    mov cl,1
    mov ch,1
    call drawtext
    test byte [frm],4
    jz .x
    mov ax,[bb_x]
    dec ax
    mov bx,[bb_y]
    dec bx
    mov cx,10
    mov dx,10
    mov si,[bb_c]
    call frame
    jmp .x
.box: mov ax,[el_ch]
    cmp ax,[di+X_CHG]
    jb .bar
    cmp byte [state],ST_WAVE
    jne .bar
    test byte [frm],4
    jz .bar
    lea si,[di+X_BOX]
    call box_frame
    lea si,[di+X_BOX2]
    call box_frame
.bar: movzx ax,byte [di+X_BOX]        ; barra de carga embaixo da caixa
    shl ax,3
    inc ax
    mov [bb_x],ax
    movzx cx,byte [di+X_BOX+2]
    sub cl,[di+X_BOX]
    inc cx
    shl cx,3
    sub cx,2
    mov [bb_w],cx
    movzx bx,byte [di+X_BOX+3]
    inc bx
    shl bx,3
    sub bx,3
    mov [bb_y],bx
    mov dx,2
    mov si,1
    call fillrect
    mov ax,[el_ch]
    mul word [bb_w]
    div word [di+X_CHG]
    cmp ax,[bb_w]
    jbe .bw
    mov ax,[bb_w]
.bw: mov cx,ax
    mov si,6
    mov ax,[el_ch]
    cmp ax,[di+X_CHG]
    jb .bc
    mov si,5
.bc: mov ax,[bb_x]
    mov bx,[bb_y]
    mov dx,2
    call fillrect
    cmp byte [fan],0
    je .x
    call draw_fans
.x: popa
    ret

draw_fans:                            ; pás girando nas duas ventoinhas da GPU
    mov word [fn_cx],116
    mov word [fn_cy],52
    xor si,si
    call .one
    mov word [fn_cx],148
    mov word [fn_cy],84
    mov si,16
    call .one
    ret
.one: xor cx,cx
.k: mov bx,[frm]
    add bx,cx
    add bx,cx
    and bx,7
    shl bx,1
    add bx,si
    mov ax,[fn_cx]
    mov [ln_x0],ax
    movsx dx,byte [fan_dir+bx]
    add ax,dx
    mov [ln_x1],ax
    mov ax,[fn_cy]
    mov [ln_y0],ax
    movsx dx,byte [fan_dir+bx+1]
    add ax,dx
    mov [ln_y1],ax
    mov al,6
    call line
    inc cx
    cmp cx,4
    jb .k
    ret

draw_pause:
    mov ax,36
    mov bx,42
    mov cx,88
    mov dx,36
    mov si,6
    call caixa
    CTEXT s_pausa,48,6,2,0,160
    CTEXT s_pcont,62,11,1,0,160
    CTEXT s_qsair,70,10,1,0,160
    ret

; =====================================================================
; dados

; ---------------------------------------------------------------------
; dados da Pessoa 1
section .data
s_core:       db 'CORE',0
s_defense:    db 'DEFENSE',0
s_jogar:      db 'JOGAR',0
s_controles:  db 'CONTROLES',0
s_sair:       db 'SAIR',0
s_gt:         db '> ',0
s_gtc:        db '>',0
s_menu_foot:  db 'W/S MOVER   ENTER OK',0
s_entervolta: db 'ENTER VOLTA',0
s_escolha:    db 'ESCOLHA O COMPONENTE',0
s_sel_foot:   db 'WASD ESCOLHE  ENTER JOGA',0
s_qvolta:     db 'Q VOLTA',0
s_ok:         db 'OK',0
s_fase_sp:    db 'FASE ',0
s_de6:        db '/6',0
s_entercomeca: db 'ENTER COMECA',0
s_torres:     db 'TORRES',0
s_tempo:      db 'TEMPO',0
s_enter:      db 'ENTER',0
s_max:        db 'MAX',0
s_t:          db 'T',0
s_2x:         db '2X',0
s_onda_sp:    db 'ONDA ',0
s_onda_sp2:   db ' ONDA ',0
s_reg:        db 'REG',0
s_novaentrada: db 'NOVA ENTRADA',0
s_limpa:      db ' LIMPA!',0
s_inimigos:   db 'INIMIGOS',0
s_bonus:      db 'BONUS ONDA',0
s_pontos:     db 'PONTOS',0
s_pontos_sp2: db 'PONTOS ',0
s_entercont:  db 'ENTER CONTINUA',0
s_enterfin:   db 'ENTER FINALIZA',0
s_kernel:     db 'KERNEL',0
s_panic:      db 'PANIC',0
s_nucleo:     db 'NUCLEO COMPROMETIDO',0
s_sistema:    db 'SISTEMA',0
s_limpo:      db 'LIMPO',0
s_traco:      db ' - ',0
s_vida:       db 'VIDA',0
s_de20:       db '/20',0
s_pausa:      db 'PAUSA',0
s_pcont:      db 'P CONTINUA',0
s_qsair:      db 'Q SAIR PARA O MENU',0
s_maischefe:  db '+CHEFE',0
s_chefe:      db 'CHEFE',0
s_sp_chefe:   db ' CHEFE',0
s_chefevenc:  db 'CHEFE VENCIDO!',0
s_elemmapa:   db 'ELEMENTO DO MAPA',0
s_chefefinal: db 'CHEFE FINAL',0
s_alerta:     db 'ALERTA: CHEFE',0
s_enterprep:  db 'ENTER PREPARA',0
s_D:          db 'D',0
ctrl_list:
    dw .k1,.d1,.k2,.d2,.k3,.d3,.k4,.d4,.k5,.d5,.k6,.d6,.k7,.d7,.k8,.d8,.k9,.d9,.k10,.d10,.k11,.d11,0
.k1: db 'WASD',0
.d1: db 'CURSOR E MIRA',0
.k2: db 'SETAS',0
.d2: db 'TAMBEM MOVEM',0
.k3: db 'ESPACO',0
.d3: db 'CONSTROI / ATIRA',0
.k4: db '1 A 4',0
.d4: db 'TORRE / HABILIDADE',0
.k5: db 'V   U',0
.d5: db 'VENDE   MELHORA',0
.k6: db 'R',0
.d6: db 'RECARGA RAPIDA',0
.k7: db 'ENTER',0
.d7: db 'INICIA ONDA',0
.k8: db 'F',0
.d8: db 'ACELERA 2X',0
.k9: db 'P / ESC',0
.d9: db 'PAUSA',0
.k10: db 'M',0
.d10: db 'SOM LIGA/DESLIGA',0
.k11: db 'ESC',0
.d11: db 'SAI (NO MENU)',0
map_flash7:    db 0,1,2,3,4,5,6,11,8,9,10,11,12,13,14,15,16
map_rootkit:   db 0,1,2,3,4,5,6,10,8,9,10,11,12,13,14,15,16
map_coreflash: db 0,1,2,3,4,8,8,8,8,9,10,8,12,13,8,15,8
