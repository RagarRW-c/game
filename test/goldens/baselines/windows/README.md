# Reviewed Windows baselines

PNGs generated locally are candidates until the owner visually reviews them.
A failed generation may leave partial or stale candidates, even if all expected
filenames exist. Preserve those files, regenerate the complete set after fixing
the failure, and review every image before approval. Missing baselines
intentionally fail ordinary verification. See
[the review workflow](../../../../qa/VISUAL_REGRESSION.md), including the optional
backup command before regenerating candidates.

After review, version-control the approved PNGs and `flutter-version.txt` here.
Keep this folder specific to the same Windows host rendering environment and
Flutter framework/engine revision. Never copy failure images here to make a
test pass. `failures/` is ignored; approved baseline PNGs are not ignored.
