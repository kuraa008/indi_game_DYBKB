import os, re

GAME = r'c:\Users\tabam\Desktop\Escape in skinwalker\game'

typed_array_re = re.compile(r'Array\s*\[\s*[A-Z]\w*(?:2D|3D)?\s*\]')
typed_var_re = re.compile(r'var\s+\w+\s*:\s*[A-Z]\w*(?:2D|3D)?\s*=')

for root, dirs, files in os.walk(GAME + r'\scripts'):
    for f in files:
        if f.endswith('.gd'):
            fp = os.path.join(root, f)
            with open(fp, 'r', encoding='utf-8', errors='ignore') as fh:
                for idx, line in enumerate(fh):
                    if typed_array_re.search(line):
                        print(f"Typed Array in {f}:{idx+1}: {line.strip()}")
