# Gera x86/data.inc a partir do mesmo modelo de dados do jogo web
import json, math, sys
import os
HERE = os.path.dirname(os.path.abspath(__file__))
D = json.load(open(os.path.join(HERE, 'gamedata.json')))
DIG = '0123456789abcdefg'
out = []
def emit(s=''): out.append(s)
def db(vals, per=32):
    vals = list(vals)
    for i in range(0, len(vals), per):
        emit('    db ' + ','.join(str(v) for v in vals[i:i+per]))
def dw(vals, per=16):
    vals = list(vals)
    for i in range(0, len(vals), per):
        emit('    dw ' + ','.join(str(v) for v in vals[i:i+per]))
def rnd(x): return int(math.floor(x + 0.5))
def s(txt): return '"' + txt.replace('"', '') + '",0'

# ---------- paleta (VGA 6 bits) ----------
emit('pal:'); pal = [0, 0, 0]
for h in D['pal']:
    pal += [int(h[1:3], 16) >> 2, int(h[3:5], 16) >> 2, int(h[5:7], 16) >> 2]
db(pal, 51)

# ---------- sprites ----------
SPR = D['spr']
names = ['bug','bug2','virus','virus2','trojan','trojan_f','worm','ransom','rootkit','firewall','scanner','quarentena','purge',
         'cpu','cpu_dano','vida','ponto','overclock','throttle','patch','antivirus','cadeado','mira','cursor','porta_on','porta_off']
keys = [p['key'] for p in D['phases']]
names += ['core_' + k for k in keys] + ['ico_' + k for k in keys]
names += ['boss_' + k for k in keys] + ['boss_' + k + '2' for k in keys]
for n in names:
    rows = SPR[n]
    emit(f'spr_{n}:'); db([len(rows[0]), len(rows)] + [DIG.index(c) for r in rows for c in r], 34)
emit('enemy_spr: dw spr_bug,spr_bug2,spr_virus,spr_virus2,spr_trojan,spr_trojan,spr_worm,spr_worm,spr_ransom,spr_ransom,spr_rootkit,spr_rootkit')
emit('tower_spr: dw 0,spr_firewall,spr_scanner,spr_quarentena,spr_purge')
emit('ab_spr: dw spr_overclock,spr_throttle,spr_patch,spr_antivirus')

# ---------- fonte 3x5, ASCII 32..95 ----------
F = D['font']
emit('font:')
for code in range(32, 96):
    g = F.get(chr(code), F['?'])
    db([int(r, 2) for r in g])

# ---------- tiles globais (4 bits por pixel, cor-1) ----------
tiles = {}; tile_list = []; maps = []
for p in D['phases']:
    b = [DIG.index(c) for c in p['bg']]
    m = []
    for ty in range(13):
        for tx in range(20):
            t = tuple(b[(ty * 8 + y) * 160 + tx * 8 + x] for y in range(8) for x in range(8))
            assert min(t) >= 1 and max(t) <= 16
            if t not in tiles: tiles[t] = len(tile_list); tile_list.append(t)
            m.append(tiles[t])
    maps.append(m)
emit(f'; {len(tile_list)} tiles')
emit('tiles:')
for t in tile_list:
    db([((t[i] - 1) << 4) | (t[i + 1] - 1) for i in range(0, 64, 2)])
for k, m in zip(keys, maps):
    emit(f'map_{k}:'); dw(m, 20)

# ---------- torres, inimigos, habilidades ----------
TOW = ['', 'firewall', 'scanner', 'quarentena', 'purge']
TT = {'firewall': (100, 1, 2, 15, 0, 0), 'scanner': (200, 1, 2, 5, 0, 0), 'quarentena': (300, 1, 2, 20, 60, 0), 'purge': (500, 2, 1, 30, 0, 1)}
emit('; cost(w) dmg r cd slow area pad')
emit('tower_tab: db 0,0,0,0,0,0,0,0')
for t in TOW[1:]:
    c, d_, r, cd, sl, ar = TT[t]
    emit(f'    dw {c}'); emit(f'    db {d_},{r},{cd},{sl},{ar},0')
emit('tower_name: dw 0,tn1,tn2,tn3,tn4')
for i, t in enumerate(TOW[1:], 1): emit(f'tn{i}: db {s(t.upper())}')
emit('ab_cost: dw 150,150,250,400')
emit('ab_name: dw an0,an1,an2,an3')
for i, n in enumerate(['OVERCLOCK', 'THROTTLE', 'PATCH', 'ANTIVIRUS']): emit(f'an{i}: db {s(n)}')
ET = ['bug', 'virus', 'trojan', 'worm', 'ransom', 'rootkit']
EB = {'bug': (3, .6, 10, 1, 8), 'virus': (2, 1.2, 20, 1, 9), 'trojan': (30, .35, 200, 5, 4), 'worm': (4, .5, 25, 1, 12),
      'ransom': (5, .5, 30, 2, 12), 'rootkit': (6, .45, 40, 2, 10)}
emit('enemy_col: db ' + ','.join(str(EB[t][4]) for t in ET))

# ---------- fases (mesmos números do jogo web, DIFF hpw .4 spd 1.15 cnt 1.2) ----------
g = lambda t, n, gap, **o: dict(t=t, n=n, gap=gap, **o)
CFG = {
 'teclado': dict(start=250, init='A', towers=[('firewall', 0)], abil=[0],
   waves=[[g('bug',6,10,word=3,pause=60)],[g('bug',9,10,word=3,pause=55)],[g('bug',12,9,word=4,pause=50)],[g('bug',15,8,word=5,pause=50),g('virus',2,80,delay=220)]]),
 'ram': dict(start=250, cap=400, init='A', open=(3,'B','CANAL B ABERTO'), spd=1.5, ptsMul=1.5, hp=dict(bug=2,virus=1,worm=3), worm=1,
   towers=[('firewall',0),('quarentena',150)], abil=[0,1],
   waves=[[g('bug',4,30,r='A')],[g('bug',6,25,r='A')],[g('bug',4,25,r='A'),g('virus',3,40,r='B',delay=30)],
          [g('bug',6,24,r='A'),g('virus',4,35,r='B'),g('worm',1,1,r='A',delay=150)],[g('bug',8,20),g('virus',6,30,delay=20),g('worm',2,90,delay=100)]]),
 'hd': dict(start=350, init='A', spd=.85, hpMul=2, worm=3, head=1, towers=[('firewall',0),('quarentena',0),('scanner',150)], abil=[0,1],
   waves=[[g('bug',10,30)],[g('bug',14,25)],[g('bug',12,25),g('virus',4,50,delay=100)],[g('bug',16,22),g('virus',6,40,delay=60),g('worm',2,120,delay=200)],
          [g('bug',20,18),g('virus',8,35),g('worm',3,100,delay=150)]]),
 'ssd': dict(start=300, init='ABC', random=1, wear=1, towers=[('firewall',0),('quarentena',0),('scanner',0)], abil=[0,1,2],
   waves=[[g('bug',8,30)],[g('bug',8,28),g('virus',4,45,delay=40)],[g('bug',10,25),g('virus',6,40),g('ransom',1,1,delay=120)],
          [g('bug',12,22),g('virus',8,35),g('ransom',2,120,delay=80)],[g('bug',16,18),g('virus',10,30),g('ransom',3,100,delay=60)]]),
 'gpu': dict(start=300, init='AB', open=(2,'CD','PISTAS C E D ABERTAS'), hp=dict(bug=1,virus=2), heat=1, area=1,
   towers=[('firewall',0),('quarentena',0),('scanner',0),('purge',150)], abil=[0,1,2,3],
   waves=[[g('bug',4,50,mode=1)],[g('bug',6,45,mode=1)],[g('bug',6,45,mode=1),g('virus',4,60,mode=2,delay=40)],[g('bug',8,40,mode=1),g('virus',6,55,mode=2)],
          [g('bug',10,36,mode=1),g('virus',8,50,mode=2)],[g('bug',12,32,mode=1),g('virus',10,45,mode=2)]]),
 'cpu': dict(start=400, init='AC', open=(4,'B','NUCLEO DE BAIXO ATIVO'), pipe=1, hpMul=1.8,
   towers=[('firewall',0),('quarentena',0),('scanner',0),('purge',0)], abil=[0,1,2,3],
   waves=[[g('bug',10,30)],[g('bug',8,30),g('virus',4,50,delay=40)],[g('bug',12,25),g('virus',6,45)],[g('bug',14,22),g('virus',8,40),g('rootkit',2,120,delay=100)],
          [g('bug',16,20),g('virus',10,36),g('rootkit',3,100,delay=80)],[g('bug',20,18),g('virus',12,32),g('rootkit',4,90,delay=60)],[g('trojan',1,1,delay=60),g('bug',20,25)]]),
}
def adj(core, c):
    x, y = core
    return any(abs(a - c[0]) + abs(b - c[1]) == 1 for a, b in [(x, y), (x + 1, y), (x, y + 1), (x + 1, y + 1)])
def build_path(p, k):
    cells = [tuple(c) for c in p['rotas'][k]]
    for _ in range(5):
        if adj(p['core'], cells[-1]): break
        for k2, r in p['rotas'].items():
            if k2 == k: continue
            r = [tuple(c) for c in r]
            if cells[-1] in r[:-1]:
                cells += r[r.index(cells[-1]) + 1:]; break
    return cells

emit('phase_tab: dw ' + ','.join('ph_' + k for k in keys))
for pi, p in enumerate(D['phases']):
    k = p['key']; C = CFG[k]; rk = list(p['rotas'].keys())
    flags = (1 if C.get('cap') else 0) | (2 if C.get('head') else 0) | (4 if C.get('wear') else 0) | (8 if C.get('random') else 0) | \
            (16 if C.get('heat') else 0) | (32 if C.get('area') else 0) | (64 if C.get('pipe') else 0)
    mask = lambda s_: sum(1 << rk.index(ch) for ch in s_)
    op = C.get('open')
    emit(f'ph_{k}:')
    emit(f'    dw pn_{k},pt_{k},pi0_{k},pi1_{k},pi2_{k},pr0_{k},pr1_{k},pr2_{k}')       # 0..15
    band = 10 if p['band'] == 15 else p['band']
    emit(f'    db {band},{flags},{p["core"][0]},{p["core"][1]}')                          # 16..19
    emit(f'    dw spr_core_{k},spr_ico_{k}')                                             # 20..23
    emit(f'    db {len(p["slots"])},{len(rk)}')                                           # 24,25
    emit(f'    dw slots_{k},routes_{k}')                                                 # 26..29
    emit(f'    db {mask(C["init"])},{op[0] if op else 0},{mask(op[1]) if op else 0},0')   # 30..33
    emit(f'    dw {"om_"+k if op else "om_none"},{C["start"]},{C.get("cap",0)}')         # 34..39
    tw_ = C['towers']
    emit(f'    db {len(tw_)},{sum(1<<i for i in C["abil"])}')                            # 40,41
    tt = [TOW.index(t) for t, _ in tw_] + [0] * (4 - len(tw_)); tn = [n for _, n in tw_] + [0] * (4 - len(tw_))
    emit('    db ' + ','.join(map(str, tt)))                                              # 42..45
    emit('    dw ' + ','.join(map(str, tn)))                                              # 46..53
    emit(f'    db {len(C["waves"])},{C.get("worm",2)}')                                  # 54,55
    emit(f'    dw waves_{k}')                                                            # 56,57
    spd = [rnd(EB[t][1] * C.get('spd', 1) * 1.15 * 16) for t in ET]
    pts = [rnd(EB[t][2] * C.get('ptsMul', 1)) for t in ET]
    emit('    db ' + ','.join(map(str, spd)))                                             # 58..63
    emit('    db ' + ','.join(str(EB[t][3]) for t in ET))                                 # 64..69
    emit('    dw ' + ','.join(map(str, pts)))                                             # 70..81
    emit(f'    dw hp_{k},map_{k}')                                                       # 82..85
    for nm, txt in [('pn', p['nome']), ('pt', p['titulo'])]: emit(f'{nm}_{k}: db {s(txt)}')
    for i, l in enumerate(p['intro']): emit(f'pi{i}_{k}: db {s(l)}')
    for i, l in enumerate(p['regras']): emit(f'pr{i}_{k}: db {s(l)}')
    if op: emit(f'om_{k}: db {s(op[2])}')
    emit(f'slots_{k}:'); db([v for sl in p['slots'] for v in sl])
    emit(f'routes_{k}:')
    for r in rk:
        cells = build_path(p, r)
        emit(f'    dw path_{k}_{r},{(len(cells)-1)*128}'); emit(f'    db {p["rotas"][r][0][0]},{p["rotas"][r][0][1]}')
    for r in rk:
        cells = build_path(p, r)
        emit(f'path_{k}_{r}:'); db([v for c in cells for v in c])
    hpt = []
    for w in range(1, len(C['waves']) + 2):          # +1: onda do chefe
        for t in ET:
            hp = C.get('hp', {}).get(t, EB[t][0]) * C.get('hpMul', 1)
            if t != 'trojan': hp = max(1, rnd(hp * (1 + .4 * (w - 1))))
            hpt.append(int(round(hp)))
    emit(f'hp_{k}:'); db(hpt, 12)
    emit(f'waves_{k}: dw ' + ','.join(f'wv_{k}_{i}' for i in range(len(C['waves']))))
    for i, wv in enumerate(C['waves']):
        emit(f'wv_{k}_{i}:')
        for gr in wv:
            emit(f'    db {ET.index(gr["t"])},{rnd(gr["n"]*1.2)},{gr["gap"]},{mask(gr["r"]) if gr.get("r") else 0},{gr.get("mode",0)},{gr.get("word",0)},{gr.get("pause",0)}')
            emit(f'    dw {gr.get("delay",0)}')
        emit('    db 255')
emit('om_none: db 0')

# ---------- elemento do mapa e chefe de cada fase (registro EXT) ----------
EL = {
 'teclado': dict(n='TECLA DE ATALHO', keys=[(7,3),(11,4),(6,6),(3,7),(12,9),(4,10)], box=None, box2=None, charge=0, hint='ATIRE NA TECLA ACESA',
   txt=['UMA TECLA ACENDE NO MEIO DA ONDA', 'ATIRE NELA: DEL DA DANO EM AREA', 'SE IGNORAR, ELA TRAVA E SOLTA UM BUG']),
 'ram': dict(n='REFRESH', box=(4,1,5,4), charge=300, hint='PENTE PISCANDO: ATIRE NELE',
   txt=['O PENTE DE MEMORIA CARREGA O REFRESH', 'ATIRE NELE QUANDO PISCAR:', 'A RAM ESQUECE E TODOS VOLTAM']),
 'hd': dict(n='BUSCA DA CABECA', box=(18,1,19,2), charge=200, hint='ATIRE NO BRACO DO HD',
   txt=['ATIRE NO BRACO DA CABECA CARREGADO', 'ELA BUSCA A TRILHA MAIS CHEIA', 'E FICA PARADA LA POR 8 SEGUNDOS']),
 'ssd': dict(n='NIVELAMENTO', box=(16,4,18,9), charge=360, hint='ATIRE NO CONTROLADOR',
   txt=['O CONTROLADOR CARREGA DEVAGAR', 'ATIRE NELE: CADA CELULA GASTA', 'RECUPERA 1 USO E AS TORRES DESTRAVAM']),
 'gpu': dict(n='VENTOINHAS', box=(12,4,17,9), box2=(17,10,19,12), charge=220, hint='ATIRE NAS VENTOINHAS',
   txt=['AS VENTOINHAS CARREGAM COM O TEMPO', 'ATIRE NELAS: O CALOR ZERA', 'E NAO SOBE POR 5 SEGUNDOS']),
 'cpu': dict(n='FLUSH', box=(14,1,15,13), charge=300, hint='ATIRE NO CACHE L3',
   txt=['O CACHE L3 CARREGA O FLUSH', 'QUEM ESTA NO PIPELINE VOLTA', '8 CASAS E PERDE O LUGAR NO EX']),
}
# flags do chefe: 1 blindado 2 furioso 4 ignora EX 8 ignora lentidao 16 esquenta
BOSS = {
 'teclado': dict(n='KEYLOGGER', hp=260, spd=.33, dmg=8, pts=300, every=80, call='bug', ncall=1, r='A',
   d=['GRAVA TUDO O QUE VOCE DIGITA', 'CHAMA 1 BUG A CADA 4S', 'TECLA DEL: DANO TRIPLO NELE'], esc=[g('bug',10,12,word=5,pause=60)]),
 'ram': dict(n='MEMORY LEAK', hp=165, spd=.5, dmg=10, pts=400, drain=4, every=100, call='virus', ncall=2, r='A',
   d=['VAZA 5 PONTOS POR SEGUNDO', 'CHAMA 2 VIRUS A CADA 5S', 'O REFRESH SO EMPURRA 1/4'], esc=[g('bug',6,25,r='A'), g('virus',6,35,r='B',delay=40)]),
 'hd': dict(n='FRAGMENTADOR', hp=700, spd=.33, dmg=12, pts=500, fl=1, split=3, r='A',
   d=['METADE DO DANO FORA DA CABECA', 'DANO DOBRADO SOB A CABECA', 'MORRE E VIRA 3 WORMS'], esc=[g('bug',14,25), g('worm',2,150,delay=200)]),
 'ssd': dict(n='CRYPTOLOCKER', hp=200, spd=.4, dmg=14, pts=600, lock=140, jump=160, r='A',
   d=['A CADA 7S TRAVA 2 TORRES', 'E GASTA O SOQUETE DELAS', 'SALTA DE PORTA EM PORTA'], esc=[g('bug',12,22), g('ransom',2,150,delay=100)]),
 'gpu': dict(n='MINERADOR', hp=320, spd=.4, dmg=16, pts=700, fl=2|16, every=90, call='virus', ncall=2, r='B',
   d=['MINERA NA GPU: ESQUENTA TUDO', 'CHAMA 2 VIRUS A CADA 4,5S', 'COM MEIA VIDA FICA RAPIDO'], esc=[g('bug',8,40,mode=1)]),
 'cpu': dict(n='ZERO-DAY', hp=380, spd=.38, dmg=20, pts=1000, fl=4|8, shield=80, half='rootkit', nhalf=3, r='A',
   d=['ESCUDO VOLTA A CADA 4S', 'NAO PARA NO EX, NEM LENTO', 'COM MEIA VIDA: 3 ROOTKITS'], esc=[g('bug',12,22), g('virus',8,40)]),
}
emit('ext_tab: dw ' + ','.join('ex_' + k for k in keys))
for p in D['phases']:
    k = p['key']; E = EL[k]; B = BOSS[k]; rk = list(p['rotas'].keys())
    mask = lambda s_: sum(1 << rk.index(ch) for ch in s_)
    bx = E.get('box') or (255, 255, 255, 255); bx2 = E.get('box2') or (255, 255, 255, 255)
    emit(f'ex_{k}:')
    emit(f'    dw xen_{k},xt0_{k},xt1_{k},xt2_{k}')                                  # 0..7
    emit('    db ' + ','.join(map(str, list(bx) + list(bx2))))                       # 8..15
    emit(f'    dw {E["charge"]},xh_{k},xbn_{k},xd0_{k},xd1_{k},xd2_{k},{B["hp"]}')   # 16..29
    emit(f'    db {rnd(B["spd"] * 1.15 * 16)},{B["dmg"]}')                            # 30,31
    emit(f'    dw {B["pts"]}')                                                        # 32,33
    emit(f'    db {B.get("every",0)},{ET.index(B["call"]) if B.get("call") else 0},{B.get("ncall",0)},{B.get("drain",0)}')   # 34..37
    emit(f'    db {B.get("fl",0)},{B.get("lock",0)},{B.get("jump",0)},{B.get("shield",0)}')                                  # 38..41
    emit(f'    db {ET.index(B["half"]) if B.get("half") else 255},{B.get("nhalf",0)},{rk.index(B["r"])},{B.get("split",0)}')  # 42..45
    emit(f'    dw xw_{k},spr_boss_{k},spr_boss_{k}2,{"xk_"+k if E.get("keys") else 0}')                                   # 46..53
    emit(f'xen_{k}: db {s(E["n"])}')
    for i, l in enumerate(E['txt']): emit(f'xt{i}_{k}: db {s(l)}')
    emit(f'xh_{k}: db {s(E["hint"])}')
    emit(f'xbn_{k}: db {s(B["n"])}')
    for i, l in enumerate(B['d']): emit(f'xd{i}_{k}: db {s(l)}')
    if E.get('keys'): emit(f'xk_{k}: db {len(E["keys"])}'); db([v for c in E['keys'] for v in c])
    emit(f'xw_{k}:')
    for gr in B['esc'] + [g('boss', 1, 1, r=B['r'], delay=60)]:
        t = 6 if gr['t'] == 'boss' else ET.index(gr['t'])
        n = 1 if gr['t'] == 'boss' else rnd(gr['n'] * 1.2)
        emit(f'    db {t},{n},{gr["gap"]},{mask(gr["r"]) if gr.get("r") else 0},{gr.get("mode",0)},{gr.get("word",0)},{gr.get("pause",0)}')
        emit(f'    dw {gr.get("delay",0)}')
    emit('    db 255')
# lâminas das ventoinhas (8 direções) para a animação
emit('fan_dir: db ' + ','.join(f'{rnd(math.cos(i*math.pi/4)*r)},{rnd(math.sin(i*math.pi/4)*r)}' for r in (20, 11) for i in range(8)))
open(os.path.join(HERE, 'data.inc'), 'w').write('\n'.join(out) + '\n')
print('ok', len(tile_list), 'tiles')
