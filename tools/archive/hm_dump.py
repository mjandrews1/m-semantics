import yottadb
name = b"^HM"
print("col0", yottadb.get(name, (b"col", b"0")))
for b in yottadb.subscripts(name, (b"col", b"1", b"")):
    n = int(yottadb.get(name, (b"col", b"1", b)) or 0)
    keys = [k.decode() for k in yottadb.subscripts(name, (b"col", b"3", b, b""))]
    if n >= 2:
        print("bucket", b.decode(), "chain_len", n, "keys", keys)
print("--- values ---")
for k in yottadb.subscripts(name, (b"col", b"2", b"")):
    v = yottadb.get(name, (b"col", b"2", k))
    print(" ", k.decode(), "=", v.decode() if v else "")
