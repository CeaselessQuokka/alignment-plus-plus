# Alignment++

A Roblox Studio plugin for aligning, attaching, aiming, resizing and placing parts and models by clicking the
exact face, edge or corner you mean.

## Hello!
If anyone is interested in making PRs please go right ahead! Any feedback, suggestions, and/or bug reports is also greatly appreciated!

Hope this plugin is at least a bit useful to your workflow :D

## Modes

| Mode | What it does |
| --- | --- |
| **Align To** | Slides the target along the direction you picked until your selection is flush with the anchor's plane. Picking the whole object instead slides it along the anchor's normal and rests it on that surface. |
| **Attach To** | Moves the target so your selection meets the anchor's exactly, in every axis. |
| **Point At** | Rotates the target in place so the direction you picked aims at the anchor's selection. |
| **Resize To** | Grows or shrinks the target so the picked face, edge or corner lands on the anchor's, leaving the opposite side put. |
| **Set To** | Copies the anchor's position, orientation and/or size onto the target. |
| **Place Between** | Centers the target between two anchor selections. |

Every mode except **Resize To** works on models as well as parts.

## Selecting

Hover a part and the face under your cursor lights up, with a handle on each of its four edges and four
corners. Whichever one you are closest to on screen is the one you will get — corners win over edges, and
edges win over the face.

Handles hold a constant size on screen, so zooming does not change how big they feel, and they are never
allowed to grow wider than a fraction of the face they sit on. That is what keeps the face of a very thin part
clickable when you are right up against it.

Handles are drawn on top of everything, so an edge buried inside a wall is still visible and still clickable —
once the cursor is over one, nothing in front can steal it.

### Knowing what will move

Clicking a wall might move the wall, the room it belongs to, or the whole building, depending on scope. So
whatever a click would actually move is always outlined in the colour of the slot it would fill:

- **Filled** — the whole object is the selection.
- **Outline only** — a face, edge or corner of it is the selection, and the outline is just showing you what
  moves when you pick it.

The selection panel says the same thing in words, naming the object and whether it is a `Part` or a `Model`,
plus which piece of it was picked.

### Modifiers

| Key | Effect |
| --- | --- |
| **Alt** (hold) | Swap between picking a face/edge/corner and picking the whole object. Each mode starts on whichever makes sense for it. |
| **Ctrl** (hold) | Deal in parts only, ignoring whatever model they sit in. This also lets a pick land inside a model an earlier pick already claimed. |
| **Shift** (hold) | Reach for the outermost model instead of the nearest one. In **Resize To** it means *extend past* instead — see below. |
| **Esc** | Cancel the whole selection. |
| **Backspace** | Undo just the last pick. |

The selection panel always spells out what the modifiers will do right now, so none of this has to be
remembered. A model selected in the Explorer still outranks all of it.

**Place Between** and **Resize To** never filter by model, so you can freely place something between two parts
of the same model without reaching for anything.

### Meeting versus extending past

A resize normally stops where the two selections meet: drag the target's face out and it lands exactly on the
point you picked. Holding **Shift** runs it on until it reaches the *plane* the anchor's face lies in instead,
which against an angled face carries on well past where they touched.

## Simple and Advanced

Out of the box the panel shows the modes and a couple of essentials, and every mode uses the defaults that
suit it best. Turn on **Advanced Mode** under *General* to reveal everything: alignment methods, what a pick
manipulates, and selection filtering.

Options that cannot apply right now are hidden rather than greyed out, so the panel only ever shows what you
can actually use.

## Building

```bash
./install.ps1
```

That installs the tooling with [Rokit](https://github.com/rojo-rbx/rokit), pulls the Wally packages, and
generates the sourcemap used by Luau LSP.

Then serve it into Studio with Rojo:

```bash
rojo serve default.project.json
```

The UI lives in `src/AlignmentPlusPlus/Assets/Ui/Main.rbxm` and is edited in Studio like any other model.
Setting rows are driven by attributes:

| Attribute | Meaning |
| --- | --- |
| `SettingDescription` | Rich text shown by the row's help button. |
| `RadioGroup` / `IsDefaultInRadioGroup` | Groups mutually exclusive options. |
| `ShowIfEnabled` | Show the row while any of the listed settings is on. |
| `ShowIfDisabled` | Hide the row as soon as any of the listed settings is on. |
| `Advanced` | Only show the row while Advanced Mode is on. |
| `Settings` (categories) | The rows that belong to the category. |

A row's name has to match a setting in `SettingsService`, and a category owns the visibility of everything it
lists.
