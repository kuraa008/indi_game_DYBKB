import os, re

GAME = r'c:\Users\tabam\Desktop\Escape in skinwalker\game'

for root, dirs, files in os.walk(GAME + r'\scripts'):
    for f in files:
        if f.endswith('.gd'):
            fp = os.path.join(root, f)
            with open(fp, 'r', encoding='utf-8', errors='ignore') as fh:
                for idx, line in enumerate(fh):
                    if '.connect(' in line:
                        # Print if connects to a method or lambda
                        if any(k in line for k in ['GameManager', 'player', 'enemy', 'door', 'noise', 'timeout', 'finished']):
                            print(f"{f}:{idx+1}: {line.strip()}")
