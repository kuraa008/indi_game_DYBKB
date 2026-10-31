import os, re, sys
sys.stdout.reconfigure(encoding='utf-8')

GAME = r'c:\Users\tabam\Desktop\Escape in skinwalker\game'

# Pattern matching typed node variables: var name: SomeNodeClass =
typed_var_re = re.compile(r'var\s+(\w+)\s*:\s*([A-Z]\w*(?:2D|3D)?)\s*(=|$)')

for root, dirs, files in os.walk(GAME + r'\scripts'):
    for f in files:
        if f.endswith('.gd'):
            fp = os.path.join(root, f)
            with open(fp, 'r', encoding='utf-8', errors='ignore') as fh:
                for idx, line in enumerate(fh):
                    m = typed_var_re.search(line)
                    if m:
                        vname, vtype = m.group(1), m.group(2)
                        # Check if type is a Node subclass
                        if any(k in vtype for k in ['Node', 'Body', 'Player', 'Enemy', 'Canvas', 'Camera', 'Light', 'Sprite', 'Control', 'Rect', 'Mesh']):
                            print(f"{f}:{idx+1}: {vname}: {vtype}")
