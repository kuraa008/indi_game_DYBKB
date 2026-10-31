import os

scripts_dir = "scripts"
errors = []

for fname in os.listdir(scripts_dir):
    if not fname.endswith(".gd"):
        continue
    fpath = os.path.join(scripts_dir, fname)
    with open(fpath, "r", encoding="utf-8") as f:
        content = f.read()
    
    # Simple check for balanced brackets ignoring strings/comments
    in_str = False
    str_ch = None
    stack = []
    lines = content.splitlines()
    for lnum, line in enumerate(lines, 1):
        stripped = line.strip()
        if stripped.startswith("#"):
            continue
        i = 0
        while i < len(line):
            ch = line[i]
            if not in_str:
                if ch in ('"', "'"):
                    # Check for triple quotes
                    if line[i:i+3] in ('"""', "'''"):
                        in_str = True
                        str_ch = line[i:i+3]
                        i += 3
                        continue
                    else:
                        in_str = True
                        str_ch = ch
                        i += 1
                        continue
                elif ch == "#":
                    break
                elif ch in "([{":
                    stack.append((ch, lnum))
                elif ch in ")]}":
                    if not stack:
                        errors.append(f"{fname}:{lnum} Unmatched {ch}")
                    else:
                        top, start_lnum = stack.pop()
                        exp = {"(": ")", "[": "]", "{": "}"}[top]
                        if ch != exp:
                            errors.append(f"{fname}:{lnum} Mismatched {ch}, expected {exp} from line {start_lnum}")
            else:
                if len(str_ch) == 3:
                    if line[i:i+3] == str_ch:
                        in_str = False
                        i += 3
                        continue
                else:
                    if ch == "\\" and i + 1 < len(line):
                        i += 2
                        continue
                    elif ch == str_ch:
                        in_str = False
            i += 1

if errors:
    print(f"Found {len(errors)} bracket errors:")
    for e in errors[:10]:
        print("  ", e)
else:
    print("All .gd scripts passed bracket matching check perfectly!")
