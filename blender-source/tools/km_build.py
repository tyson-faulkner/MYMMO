"""Headless build driver for the Kingsmourn kit.

Usage:
    blender --background --python km_build.py -- <piece_module> [more...]

For each named piece module it calls build(), renders a preview into
docs/reference/kit-previews/, saves the .blend into blender-source/, and
exports the .glb into godot-project/assets/kit/.
"""

import os
import sys
import importlib
import traceback

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import km_kit as K  # noqa: E402


def run(module_name):
    mod = importlib.import_module(module_name)
    importlib.reload(mod)

    objs = mod.build()
    print("[%s] %s" % (mod.NAME, K.report(objs)))

    K.preview_rig()
    preview = os.path.join(K.PREVIEW_DIR, "%s.png" % getattr(mod, "PREVIEW", mod.NAME))
    angles = getattr(mod, "ANGLES", (38, -128))
    elevation = getattr(mod, "ELEVATION", 26)
    K.render_views(objs, preview, angles=angles, elevation=elevation,
                   repeat=getattr(mod, "REPEAT", None))
    print("[%s] preview -> %s" % (mod.NAME, preview))

    blend = K.save_blend(mod.NAME)
    print("[%s] blend   -> %s" % (mod.NAME, blend))

    glb = K.export_glb(objs, mod.NAME)
    size = os.path.getsize(glb)
    print("[%s] glb     -> %s (%d bytes)" % (mod.NAME, glb, size))
    return glb


def main():
    argv = sys.argv
    args = argv[argv.index("--") + 1:] if "--" in argv else []
    if not args:
        print("no piece modules given")
        return 1
    failed = 0
    for name in args:
        try:
            run(name)
        except Exception:
            failed += 1
            print("FAILED %s" % name)
            traceback.print_exc()
    print("DONE failed=%d" % failed)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
