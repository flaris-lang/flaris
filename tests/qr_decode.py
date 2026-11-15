#!/usr/bin/env python3
"""Independent QR Code checker for tests/test_qrcode.fls (standard library only).

Reads lines "QR|<ecLevel>|<size>|<hex payload>|<bits>" from the file named as
the first argument, or from stdin without one: ecLevel as
QRCode numbers it (0 M, 1 L, 2 H, 3 Q), size the symbol's side in modules with
the 4-module quiet zone, the payload as hex, and the modules row-major as 0/1.
Byte mode, versions 1-10. Each symbol is checked against ISO/IEC 18004: quiet
zone, finder, timing and alignment patterns, both format-information copies
and their BCH code, version information, the dark module, every Reed-Solomon
block's syndromes, the payload after unmasking, and that the version is the
smallest that fits. Prints one line per bad symbol, then
"decoded OK: <n>  BAD: <m>".
"""
import sys
# (ver, ec) -> (ec_per_block, g1, d1, g2, d2); ec index: L,M,Q,H  (ISO 18004 table 9)
T = {
1:{'L':(7,1,19,0,0),'M':(10,1,16,0,0),'Q':(13,1,13,0,0),'H':(17,1,9,0,0)},
2:{'L':(10,1,34,0,0),'M':(16,1,28,0,0),'Q':(22,1,22,0,0),'H':(28,1,16,0,0)},
3:{'L':(15,1,55,0,0),'M':(26,1,44,0,0),'Q':(18,2,17,0,0),'H':(22,2,13,0,0)},
4:{'L':(20,1,80,0,0),'M':(18,2,32,0,0),'Q':(26,2,24,0,0),'H':(16,4,9,0,0)},
5:{'L':(26,1,108,0,0),'M':(24,2,43,0,0),'Q':(18,2,15,2,16),'H':(22,2,11,2,12)},
6:{'L':(18,2,68,0,0),'M':(16,4,27,0,0),'Q':(24,4,19,0,0),'H':(28,4,15,0,0)},
7:{'L':(20,2,78,0,0),'M':(18,4,31,0,0),'Q':(18,2,14,4,15),'H':(26,4,13,1,14)},
8:{'L':(24,2,97,0,0),'M':(22,2,38,2,39),'Q':(22,4,18,2,19),'H':(26,4,14,2,15)},
9:{'L':(30,2,116,0,0),'M':(22,3,36,2,37),'Q':(20,4,16,4,17),'H':(24,4,12,4,13)},
10:{'L':(18,2,68,2,69),'M':(26,4,43,1,44),'Q':(24,6,19,2,20),'H':(28,6,15,2,16)},
}
AP = {1:[],2:[6,18],3:[6,22],4:[6,26],5:[6,30],6:[6,34],7:[6,22,38],8:[6,24,42],9:[6,26,46],10:[6,28,50]}
EXP=[0]*512; LOG=[0]*256; x=1
for i in range(255):
    EXP[i]=x; LOG[x]=i; x<<=1
    if x&256: x^=0x11D
for i in range(255,512): EXP[i]=EXP[i-255]
def mul(a,b): return 0 if a==0 or b==0 else EXP[LOG[a]+LOG[b]]
def synd_ok(block, nsym):
    for i in range(nsym):
        s=0
        for c in block: s=mul(s,EXP[i])^c
        if s: return False
    return True
def bch_fmt(d5):
    v=d5<<10
    for i in range(14,9,-1):
        if v>>i&1: v^=0x537<<(i-10)
    return ((d5<<10)|v)^0x5412
def bch_ver(v6):
    v=v6<<12
    for i in range(17,11,-1):
        if v>>i&1: v^=0x1F25<<(i-12)
    return (v6<<12)|v
MASK=[lambda r,c:(r+c)%2==0, lambda r,c:r%2==0, lambda r,c:c%3==0, lambda r,c:(r+c)%3==0,
      lambda r,c:(r//2+c//3)%2==0, lambda r,c:(r*c)%2+(r*c)%3==0, lambda r,c:((r*c)%2+(r*c)%3)%2==0,
      lambda r,c:((r+c)%2+(r*c)%3)%2==0]
ok=bad=0
for line in (open(sys.argv[1]) if len(sys.argv) > 1 else sys.stdin):
    if not line.startswith('QR|'): 
        if line.strip(): print('other:',line.strip()[:80])
        continue
    _,ec,full,hx,bits=line.strip().split('|')
    text=bytes.fromhex(hx); full=int(full); n=full-8
    g=[[int(bits[r*full+c]) for c in range(full)] for r in range(full)]
    err=[]
    # quiet zone
    for r in range(full):
        for c in range(full):
            if (r<4 or r>=full-4 or c<4 or c>=full-4) and g[r][c]: err.append('quiet'); break
    m=[row[4:4+n] for row in g[4:4+n]]
    ver=(n-17)//4
    fn=[[False]*n for _ in range(n)]
    def mark(r0,c0,h,w):
        for r in range(r0,r0+h):
            for c in range(c0,c0+w):
                if 0<=r<n and 0<=c<n: fn[r][c]=True
    mark(0,0,9,9); mark(0,n-8,9,8); mark(n-8,0,8,9)
    for i in range(n): fn[6][i]=True; fn[i][6]=True
    # finder check
    F=["1111111","1000001","1011101","1011101","1011101","1000001","1111111"]
    for (r0,c0) in ((0,0),(0,n-7),(n-7,0)):
        for r in range(7):
            for c in range(7):
                if m[r0+r][c0+c]!=int(F[r][c]): err.append('finder')
    for i in range(8,n-8):
        if m[6][i]!=(i+1)%2 or m[i][6]!=(i+1)%2: err.append('timing')
    pos=AP[ver]
    for a in pos:
        for b in pos:
            if (a==6 and b==6) or (a==6 and b==pos[-1]) or (a==pos[-1] and b==6): continue
            mark(a-2,b-2,5,5)
            for dr in range(-2,3):
                for dc in range(-2,3):
                    exp=1 if max(abs(dr),abs(dc))!=1 else 0
                    if m[a+dr][b+dc]!=exp: err.append('align')
    if m[n-8][8]!=1: err.append('darkmodule')
    if ver>=7:
        mark(0,n-11,6,3); mark(n-11,0,3,6)
        v1=sum(m[i//3][n-11+i%3]<<i for i in range(18)); v2=sum(m[n-11+i%3][i//3]<<i for i in range(18))
        if v1!=bch_ver(ver) or v2!=v1: err.append('versioninfo %x %x want %x'%(v1,v2,bch_ver(ver)))
    rs=[8]*8+[7,5,4,3,2,1,0]; cs=[0,1,2,3,4,5,7,8]+[8]*7
    f1=0
    for i in range(15): f1=(f1<<1)|m[rs[i]][cs[i]]
    f2=0
    for i in range(7): f2=(f2<<1)|m[n-1-i][8]
    for i in range(8): f2=(f2<<1)|m[8][n-8+i]
    if f1!=f2: err.append('fmt copies differ %x %x'%(f1,f2))
    d5=(f1^0x5412)>>10
    if bch_fmt(d5)!=f1: err.append('fmt bch')
    ecn={1:'L',0:'M',3:'Q',2:'H'}[d5>>3]; mask=d5&7
    libec={'0':'M','1':'L','2':'H','3':'Q'}[ec]
    if ecn!=libec: err.append('ec level in fmt %s want %s'%(ecn,libec))
    # read data
    out=[]; col=n-1; up=True
    while col>0:
        if col==6: col-=1
        rng=range(n-1,-1,-1) if up else range(n)
        for r in rng:
            for c in (col,col-1):
                if not fn[r][c]: out.append(m[r][c]^(1 if MASK[mask](r,c) else 0))
        up=not up; col-=2
    ecpb,g1,d1,g2,d2=T[ver][ecn]
    nb=g1+g2; tot=g1*d1+g2*d2+nb*ecpb
    if len(out)//8!=tot: err.append('module count %d want %d cw'%(len(out),tot))
    cw=[int(''.join(map(str,out[i*8:i*8+8])),2) for i in range(tot)]
    sizes=[d1]*g1+[d2]*g2
    blocks=[[] for _ in range(nb)]; k=0
    for j in range(max(sizes)):
        for b in range(nb):
            if j<sizes[b]: blocks[b].append(cw[k]); k+=1
    for j in range(ecpb):
        for b in range(nb): blocks[b].append(cw[k]); k+=1
    for b in range(nb):
        if not synd_ok(blocks[b],ecpb): err.append('RS block %d'%b)
    data=[]
    for b in range(nb): data+=blocks[b][:sizes[b]]
    bs=''.join('{:08b}'.format(x) for x in data)
    if bs[:4]!='0100': err.append('mode '+bs[:4])
    cb=8 if ver<10 else 16
    cnt=int(bs[4:4+cb],2)
    payload=bytes(int(bs[4+cb+8*i:4+cb+8*i+8],2) for i in range(cnt))
    if payload!=text: err.append('payload mismatch')
    # smallest version check
    need=4+8*len(text)
    for v in range(1,11):
        e=T[v][ecn]; cap=(e[1]*e[2]+e[3]*e[4])*8
        if cap>=need+(8 if v<10 else 16): break
    if v!=ver: err.append('version %d, smallest is %d'%(ver,v))
    if err: bad+=1; print('BAD len=%d ec=%s ver=%d:'%(len(text),libec,ver), sorted(set(err))[:6])
    else: ok+=1
print('decoded OK:',ok,' BAD:',bad)
