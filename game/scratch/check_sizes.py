import json

for path in ["scenes/Карта_4.json", "scenes/Карта_6.json", "scenes/test.json", "assets/prototype map.json"]:
    try:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
            objs = data.get("objects", [])
            big_objs = []
            for o in objs:
                s = o.get("scale", [1,1,1])
                mag = max(s)
                if mag > 35:
                    big_objs.append((o.get("type"), o.get("name"), s))
            print(f"{path}: total {len(objs)} objects, {len(big_objs)} > 35m")
            for b in big_objs[:5]:
                print(f"   {b[0]} '{b[1]}': {b[2]}")
    except Exception as e:
        print(f"Error {path}: {e}")
