# Tidy — in-game test pass

One pass, in order. Note the number of anything that fails (and paste any Lua error).

## Start
1. `/reload`. No Lua errors on login.
2. Blizzard action bars are gone; Tidy bars show your spells and keybinds.

## General
3. **Unlock bars** (window header): every bar shows a blue box with its name on a tag above (also pet, stance, micro, bags, XP, extra, vehicle, queue). Bars that show nothing now show a faded sample (pet icons, a form, the extra button, the leave vehicle button, the queue eye, an XP bar); action bars show their empty slots.
4. Drag a bar: only the guide lines near it show (faint); the one it sticks to turns bright. Drop: it stays.
5. Click a bar (no drag): the panel opens on that bar.
6. **Keybinding mode** (window header): hover a button, press a key → the key shows on it. Esc leaves.
7. **Enabled** off → Blizzard's bars come back, no errors, no empty boxes. On again → Tidy's back.
8. Each **Preset** (Blizzard-like, Compact, Split) moves bars 1 and 3-6.
9. Bars → Bar 1 → Layout → **Gryphons** on/off (greyed on every other bar); **Reset this bar** on bar 1 turns them off again.

## One bar (Bar 1, then Pet bar, then Bags) — tabs Layout · Visibility · Actions
10. **Show this bar** off hides it (Blizzard's does not come back). Layout: buttons, rows, padding, button width/height, icon fit, scale, opacity, fill direction, click-through all change it at once.
11. X / Y typed values move it; **Center horizontally / vertically**.
12. **Reset this bar** puts it back.
13. Visibility: fade (mouse out → faded after the delay), each hide option, custom `[combat] show; hide`.
14. Actions, paging (bar 1): Shift+2 changes page and the texts; Ctrl / Alt / Shift pages; stance pages (if your class has them).
15. Actions, this bar's buttons (bar 1): empty buttons, hide macro / keybind / equipped, flyout direction.
16. Bags: **Only the backpack**, **Keyring**. Extra button: **Hide the artwork** (needs an extra button).

## Buttons — tabs Behaviour (with casting) · States · Timers · Flashes · Texts
Each look tab: list on the left (check = on/off, swatch = color), the picked one on the right with a sample button, **Defaults** under the list (only that tab).
17. Tooltips always / out of combat / never. Behaviour **Defaults**: tooltips, lock and casting back.
18. **Lock buttons**: spells can't be dragged off (Shift+drag can).
19. Drag a spell between buttons: it moves, it is **not** cast.
20. **Texts**: keybind, count, macro name, cooldown — on/off, font, size, outline, color, position; the sample shows it.
21. Casting: self-cast key, focus-cast key, mouse-over, right click on yourself.
21b. Click a button while moving the mouse (starts a drag): it never stays darker afterwards.
21c. **Flashes**: press a spell on cooldown → red; during the global cooldown only → yellow; not usable / out of range / no mana → orange; key of an empty slot → white; a 2 s+ cooldown ends → green; interrupted cast (flat) → red. Each on/off and color works; Interrupted greyed with the Blizzard cast style.
21d. **States > Hover / Pressed / Active** (square look on): hover tint, pressed while held (never stays, also changing Shift), active (current stance, queued Raptor Strike / Heroic Strike). Each off: nothing shows. Square look off: greyed, Blizzard's look.
21e. **Timers**: global cooldown swipe lighter than a real cooldown; spark on/off and color; Casting off / flat (fill color) / Blizzard.
21f. **States > Not usable / Out of mana / Out of range**: colors; off = the icon keeps its colors; out of range tints the button or the keybind.
21g. **States > Attacking**: Auto Attack flashes in its color while attacking; **Auto-repeat**: Auto Shot / Shoot flash in theirs. Off: no flash.
21h. **States > Equipped**: equipped item (trinket on a bar) border in its color; off = no border; Bars > Actions "Hide equipped border" still hides it per bar.
21i. Old settings: a profile with out of range "Nothing" opens with Out of range unchecked.

## Icons
22. Each place on/off: icons square ↔ Blizzard's look, live.
23. Border size / color, background, zoom, debuff and quality colors. Icons **Defaults** keeps the places and the button states (Buttons > States).

## Profiles
24. New profile → defaults; switch back → your setup. Copy, reset, delete.
25. Export → Import the same text: nothing changes.

## Combat
26. Change a bar setting in combat: it applies when combat ends, no errors.
