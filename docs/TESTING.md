# Tidy — in-game test pass

One pass, in order. Note the number of anything that fails (and paste any Lua error).

## Start
1. `/reload` with Bartender4 **off**. No Lua errors on login.
2. Blizzard action bars are gone; Tidy bars show your spells and keybinds.

## All bars
3. **Unlock bars**: every bar shows a blue box with its name on a tag above (also pet, stance, micro, bags, XP, extra, vehicle, queue). Bars that show nothing now show a faded sample (pet icons, a form, the extra button, the leave vehicle button, the queue eye, an XP bar); action bars show their empty slots.
4. Drag a bar: only the guide lines near it show (faint); the one it sticks to turns bright. Drop: it stays.
5. Click a bar (no drag): the panel opens on that bar.
6. **Keybinding mode**: hover a button, press a key → the key shows on it. Esc leaves.
7. **Enabled** off → Blizzard's bars come back, no errors, no empty boxes. On again → Tidy's back.
8. Each **Preset** (Blizzard-like, Compact, Split) moves bars 1 and 3-6.
9. **Gryphons on bar 1** on/off.

## One bar (Bar 1, then Pet bar, then Bags)
10. **Show this bar** off hides it (Blizzard's does not come back). Layout: buttons, rows, padding, button width/height, icon fit, scale, opacity, fill direction, click-through all change it at once.
11. X / Y typed values move it; **Center horizontally / vertically**.
12. **Reset this bar** puts it back.
13. Visibility: fade (mouse out → faded after the delay), each hide option, custom `[combat] show; hide`.
14. Paging (bar 1): Shift+2 changes page and the texts; Ctrl / Alt / Shift pages; stance pages (if your class has them).
15. Buttons (bar 1): empty buttons, hide macro / keybind / equipped, flyout direction.
16. Bags: **Only the backpack**, **Keyring**. Extra button: **Hide the artwork** (needs an extra button).

## Buttons
17. Tooltips always / out of combat / never. Out of range colors.
18. **Lock buttons**: spells can't be dragged off (Shift+drag can).
19. Drag a spell between buttons: it moves, it is **not** cast.
20. Texts: show / hide, font, size, outline, color, position for keybind, count, macro name.
21. Casting: self-cast key, focus-cast key, mouse-over, right click on yourself.
21b. Click a button while moving the mouse (starts a drag): it never stays darker afterwards.
21c. Press the key of a spell on cooldown: short red flash. Not on a normal cast, not during the global cooldown only. **Pressed on cooldown** color / opacity 0 = off.
21d. Press a key: the button looks pressed while held (flat and Blizzard states), never stays pressed (also changing Shift while holding).
21e. Global cooldown swipe lighter than a real cooldown (**Global cooldown darkness**); a spell with its own cooldown uses **Cooldown darkness**.
21f. A spell you cannot use (wrong form, no target needed...) uses **Not usable color**.
21g. Press a spell out of range / without mana / not usable: orange flash (**Pressed when not usable**, opacity 0 = off). Empty buttons: no flash.

## Icons
22. Each place on/off: icons square ↔ Blizzard's look, live.
23. Border size / color, background, zoom, debuff and quality colors.

## Profiles
24. New profile → defaults; switch back → your setup. Copy, reset, delete.
25. Export → Import the same text: nothing changes.

## Combat
26. Change a bar setting in combat: it applies when combat ends, no errors.
