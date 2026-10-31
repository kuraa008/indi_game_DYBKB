import os, sys
sys.stdout.reconfigure(encoding='utf-8')

GAME = r'c:\Users\tabam\Desktop\Escape in skinwalker\game'

for root, dirs, files in os.walk(GAME + r'\scripts'):
    for f in files:
        if f.endswith('.gd'):
            fp = os.path.join(root, f)
            with open(fp, 'r', encoding='utf-8', errors='ignore') as fh:
                for idx, line in enumerate(fh):
                    if 'GameManager.player_ref.' in line or 'GameManager.enemy_ref.' in line or 'GameManager.ui_ref.' in line:
                        print(f"{f}:{idx+1}: {line.strip()}")
