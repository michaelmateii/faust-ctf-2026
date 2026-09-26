#!/usr/bin/env python3
import sys, struct, subprocess, tempfile, os
from urllib.parse import unquote_to_bytes

if len(sys.argv) != 2:
    print(f"usage: {sys.argv[0]} <receiptcode-file>")
    raise SystemExit(1)

s=open(sys.argv[1], encoding="latin1").read().strip()
b=unquote_to_bytes(s)

off=struct.unpack_from("<I",b,10)[0]
dib=struct.unpack_from("<I",b,14)[0]
w=struct.unpack_from("<i",b,18)[0]
h=struct.unpack_from("<i",b,22)[0]
pal=14+dib
stride=((w+3)//4)*4

def rgb(i):
    p=pal+4*i
    B,G,R,_=b[p:p+4]
    return R,G,B

rows=[]
for y in range(abs(h)):
    sy=y if h < 0 else abs(h)-1-y
    rows.append(list(b[off+sy*stride:off+sy*stride+w]))

q=4
scale=12

for name,ch in [("red",0),("green",1),("blue",2)]:
    W=w+2*q
    H=abs(h)+2*q
    fn=f"/tmp/ruff-{name}.pgm"

    with open(fn,"wb") as f:
        f.write(f"P5\n{W*scale} {H*scale}\n255\n".encode())

        modules=[[255]*W for _ in range(q)]
        for row in rows:
            line=[255]*q
            line += [0 if rgb(idx)[ch] == 0 else 255 for idx in row]
            line += [255]*q
            modules.append(line)
        modules += [[255]*W for _ in range(q)]

        for row in modules:
            expanded=b''.join(bytes([x])*scale for x in row)
            for _ in range(scale):
                f.write(expanded)

    p=subprocess.run(
        ["zbarimg","--raw",fn],
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True
    )

    print(f"[{name}] {p.stdout.strip()}")
