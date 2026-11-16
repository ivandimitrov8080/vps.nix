from yaml import safe_load, dump
from sys import argv
from subprocess import run
from pathlib import Path

src = Path(argv[1]).resolve()
config = Path(argv[2]).resolve()

def encrypt(contents):
    return run(["sops", "--config", str(config), "encrypt", "--filename-override", str(src)], input=contents, capture_output=True, text=True, encoding="utf-8")


with open(src, "r") as f:
    kv = safe_load(f)
    kv.pop("sops", None)
    for k in kv:
        kv[k] = "test" * 8
    res = encrypt(dump(kv))
    if res.returncode != 0:
        print(res)
    else:
        print(res.stdout)


