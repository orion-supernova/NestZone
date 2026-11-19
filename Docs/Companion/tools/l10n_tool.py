"""Apply a spec of string changes to L10n.swift and Localizable.xcstrings.

Usage: python3 Docs/Companion/tools/l10n_tool.py spec.json

Spec (JSON):
{
  "section": "MARK title for added accessors",
  "add": [ {"accessor": "x", "key": "x_key", "args": ["String", "Int"],
            "en": "...", "tr": "...",               # or
            "en_one": "...", "en_other": "...", "tr_one": "...", "tr_other": "..."} ],
  "update": [ {"key": "k", "en": "...", "tr": "..."} ],
  "remove": ["key", ...]
}
"""
import json
import re
import sys

# The app's sources, found from this file: Docs/Companion/tools/ → the repo root.
ROOT = str(__import__("pathlib").Path(__file__).resolve().parents[3] / "NestZone")
SWIFT = f"{ROOT}/Core/Localization/L10n.swift"
CATALOG = f"{ROOT}/Resources/Localizable.xcstrings"


def unit(value):
    return {"stringUnit": {"state": "translated", "value": value}}


def localization(entry, lang):
    if f"{lang}_other" in entry:
        plural = {"other": unit(entry[f"{lang}_other"])}
        if entry.get(f"{lang}_one") is not None:
            plural["one"] = unit(entry[f"{lang}_one"])
        return {"variations": {"plural": plural}}
    return unit(entry[lang])


def swift_default(fmt, args):
    """'%1$@ is %2$lld days' -> '\\(a0) is \\(a1) days'."""
    counter = iter(range(len(args)))

    def repl(m):
        pos = m.group(1)
        index = int(pos) - 1 if pos else next(counter)
        return f"\\(a{index})"

    out = re.sub(r"%(?:(\d+)\$)?(?:@|lld|d)", repl, fmt)
    return out.replace('"', '\\"')


def accessor(entry):
    args = entry.get("args", [])
    en = entry.get("en") or entry.get("en_other")
    doc = f"    /// {en}\n"
    default = swift_default(en, args)
    if args:
        params = ", ".join(f"_ a{i}: {t}" for i, t in enumerate(args))
        return (doc + f"    public static func {entry['accessor']}({params}) -> LocalizedStringResource {{\n"
                f"        r(\"{entry['key']}\", \"{default}\")\n    }}\n")
    return (doc + f"    public static var {entry['accessor']}: LocalizedStringResource {{\n"
            f"        r(\"{entry['key']}\", \"{default}\")\n    }}\n")


def main(spec_path):
    spec = json.load(open(spec_path, encoding="utf-8"))
    swift = open(SWIFT, encoding="utf-8").read()
    catalog = json.load(open(CATALOG, encoding="utf-8"))
    strings = catalog["strings"]

    for key in spec.get("remove", []):
        strings.pop(key, None)
        pattern = re.compile(
            r"\n(    /// [^\n]*\n)*    public static (var|func) \w+[^\n]*\{\n        r\(\"" + re.escape(key) + r"\"[^\n]*\n    \}\n"
        )
        swift, n = pattern.subn("\n", swift)
        if n == 0:
            print(f"warning: no accessor for removed key {key}", file=sys.stderr)

    for entry in spec.get("update", []):
        key = entry["key"]
        if key not in strings:
            print(f"warning: update of unknown key {key}", file=sys.stderr)
            continue
        strings[key]["localizations"] = {"en": localization(entry, "en"), "tr": localization(entry, "tr")}
        en = entry.get("en") or entry.get("en_other")
        m = re.search(r"(    /// )[^\n]*\n(    public static (?:var|func) \w+[^\n]*\{\n        r\(\"" + re.escape(key) + r"\", \")([^\n]*)(\"\)\n)", swift)
        if not m:
            print(f"warning: no accessor for updated key {key}", file=sys.stderr)
            continue
        sig = m.group(2)
        argc = len(re.findall(r"_ a\d+:", sig))
        new_default = swift_default(en, ["x"] * argc)
        swift = swift[:m.start()] + f"    /// {en}\n" + sig + new_default + m.group(4) + swift[m.end():]

    added = []
    for entry in spec.get("add", []):
        if entry["key"] in strings:
            print(f"warning: key {entry['key']} already exists; skipped", file=sys.stderr)
            continue
        strings[entry["key"]] = {
            "extractionState": "manual",
            "localizations": {"en": localization(entry, "en"), "tr": localization(entry, "tr")},
        }
        added.append(accessor(entry))

    if added:
        block = f"\n    // MARK: - {spec.get('section', 'Added')}\n\n" + "\n".join(added)
        last = swift.rstrip().rfind("}")
        swift = swift[:last].rstrip("\n") + "\n" + block + "}\n"

    open(SWIFT, "w", encoding="utf-8").write(swift)
    with open(CATALOG, "w", encoding="utf-8") as f:
        f.write(json.dumps(catalog, indent=2, ensure_ascii=False, sort_keys=True) + "\n")
    print(f"added {len(added)}, updated {len(spec.get('update', []))}, removed {len(spec.get('remove', []))}")


if __name__ == "__main__":
    main(sys.argv[1])
