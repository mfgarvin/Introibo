# Launch Screen Assets

**Generated — do not hand-edit and do not drop images in from Xcode.**

`LaunchImage*.png` is rendered from the design handoff's vector source by
`tool/gen_icons.py`, exactly like every app-store and launcher icon, so the
launch mark can never drift from the app icon. Regenerate with:

    python3 tool/gen_icons.py          # write
    python3 tool/gen_icons.py --check  # verify the tree matches the vector

The mark is drawn on **transparency** (unlike the app icon, which Apple rejects
if it carries an alpha channel) so the storyboard's `LaunchBackground` colour
shows through — parchment in light appearance, black in dark, matching
`kBackgroundColor` / `kBackgroundColorDark` in `lib/main.dart`. Change the size
via `LAUNCH_PT` in the script, and keep the `<image>` dimensions in
`../../Base.lproj/LaunchScreen.storyboard` in step with it.
