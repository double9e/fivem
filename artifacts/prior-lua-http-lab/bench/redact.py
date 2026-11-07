import os,sys,re
k=os.environ.get("FX_LICENSE",""); ansi=re.compile(r'\x1b\[[0-9;]*m')
for line in sys.stdin:
    if k: line=line.replace(k,"[REDACTED]")
    sys.stdout.write(ansi.sub("",line)); sys.stdout.flush()
