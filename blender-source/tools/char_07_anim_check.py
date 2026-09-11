"""Animation check -- renders key frames of Run and Attack1 as a filmstrip.

The Godot check proves the clips exist and are named right. It cannot tell
you whether the character is running or falling over. This renders the
poses so they can be judged.

Test render only; exports nothing.
"""

import numpy as np
import bpy

import km_kit as K
import km_anim
import char_03_valkyr as valkyr

NAME = "char_anim_check"
EXPORT = False
STRIPS = [("Run", [1, 7, 13, 19]), ("Attack1", [1, 4, 10, 16])]
YAW = 58
ELEVATION = 8


def build():
    objs = valkyr.build()
    km_anim.build_all(objs[0])
    return objs


def render(objs, out_path):
    arm_obj = objs[0]
    rows = []
    for clip_name, frames in STRIPS:
        action = bpy.data.actions[clip_name]
        arm_obj.animation_data.action = action
        shots = []
        for f in frames:
            bpy.context.scene.frame_set(f)
            bpy.context.view_layer.update()
            shots.append(K._render_strip(objs, (YAW,), ELEVATION,
                                         res=(430, 620)))
        gap = np.ones((shots[0].shape[0], 6, 4))
        row = shots[0]
        for s in shots[1:]:
            row = np.concatenate([row, gap, s], axis=1)
        rows.append(row)

    width = max(r.shape[1] for r in rows)
    padded = []
    for r in rows:
        if r.shape[1] < width:
            fill = np.ones((r.shape[0], width - r.shape[1], 4))
            r = np.concatenate([r, fill], axis=1)
        padded.append(r)
    strip = padded[0]
    for r in padded[1:]:
        strip = np.concatenate([strip, np.ones((6, width, 4)), r], axis=0)
    strip[:, :, 3] = 1.0
    import km_textures
    km_textures.save_png(strip, out_path)
    return out_path


if __name__ == "__main__":
    print(K.report(build()))
