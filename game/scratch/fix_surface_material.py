import re

files_to_fix = ["scripts/PrefabBuilder.gd", "scripts/Street.gd", "scripts/Item.gd", "scripts/DebugEditor.gd"]

for fpath in files_to_fix:
    with open(fpath, "r", encoding="utf-8") as f:
        content = f.read()

    # Pattern: mesh_var.surface_set_material(0, mat_var) -> mesh_var.material = mat_var
    pattern = r"(\b\w+)\.surface_set_material\(0,\s*([^)]+)\)"
    
    matches = re.findall(pattern, content)
    print(f"{fpath}: found {len(matches)} occurrences")
    if matches:
        new_content = re.sub(pattern, r"\1.material = \2", content)
        with open(fpath, "w", encoding="utf-8") as f:
            f.write(new_content)
        print(f"  Fixed {fpath} successfully!")
