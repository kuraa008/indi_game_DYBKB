import os, re

GAME = r'c:\Users\tabam\Desktop\Escape in skinwalker\game'

typed_loop_re = re.compile(r'for\s+\w+\s*:\s*[A-Z]\w+\s+in')

print("Scanning for typed loops...")
for root, dirs, files in os.walk(GAME + r'\scripts'):
    for f in files:
        if f.endswith('.gd'):
            fp = os.path.join(root, f)
            with open(fp, 'r', encoding='utf-8', errors='ignore') as fh:
                for idx, line in enumerate(fh):
                    if typed_loop_re.search(line):
                        print(f"Typed loop in {f}:{idx+1}: {line.strip()}")
                    if ': CollisionShape3D' in line and 'for ' in line:
                        print(f"Col loop in {f}:{idx+1}: {line.strip()}")
