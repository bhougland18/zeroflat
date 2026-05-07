# zeroflat Components — Agent Skill File

> **STATUS: Vocabulary current; Architecture Refined.**
> This document defines the **rendering contract** between the Rust core
> and the Flutter UI library. It leverages the Forui mapping logic
> harvested from `stac-forui-components`.
>
> - **Wire Format:** FlatBuffers (codegen for Rust and Dart).
> - **Responsibility:** Flutter is a **stateless renderer**. Rust owns all
>   logic, state, and P2P orchestration.
> - **Heritage:** Enum mappings, slot configurations, and widget
>   attachments are derived from the `stac-forui-components` project
>   to ensure consistency and speed.

> **Audience.** An AI agent (Claude, Gemini, etc.) authoring UI
> payloads during development. Read this when asked to "build a
> screen," "add a component," or "modify the layout." This file
> describes the *available vocabulary* that the Flutter renderer
> understands.
>
> **Source.** Distilled from `~/code/stac-forui-components/lib/src/models/`
> (the prior STAC integration that maps the same Forui widget set).
> When in doubt about a Forui-specific behavior, that repo is the
> reference implementation.

---

## 0. How the agent uses this file

When the developer asks for a UI change, the agent:

1. Picks components from §6 that satisfy the request.
2. Composes them into a `StacRoot` tree (§3).
3. References color and typography by **token name** (§5), never hex.
4. Wires interactions as `StacAction` values (§4).
5. Writes the resulting payload to the dev hot-reload target
   (file watcher; path TBD in the dev tooling spec).
6. Iterates with the developer based on what renders.

The agent does **not**:

- Invent new component types not listed in §6.
- Use hex color values; they are not in the schema.
- Write fbs binary directly; emit JSON-shaped payloads that the dev
  toolchain converts to fbs (the `.fbs` schema is the converter's
  source of truth).
- Fabricate `id`s — every component **must** have a stable `id`.
  Reuse the same `id` across iterations of the same logical component
  so deltas land correctly.

---

## 1. Conceptual model

```
┌─────────────────┐       ┌─────────────────┐       ┌─────────────────┐
│ StacRoot        │       │ Component (e.g. │       │ StacAction      │
│  schema_version │  ─►   │  Button)        │  ─►   │  (union)        │
│  node: StacNode │       │  id: string     │       │   ActionNavigate│
└─────────────────┘       │  ...fields      │       │   ActionUpdate  │
                          │  on_press?      │       │   ActionShow*   │
                          └─────────────────┘       │   ActionCustom  │
                                                    └─────────────────┘
```

- **`StacNode`** is a union over every component type in §6. Every
  branch is a table with at least an `id` and component-specific fields.
- **`StacAction`** is a union over the action types in §4.
- **Tokens** (color, typography) are `ushort` enums in the `.fbs`
  schema; in JSON they appear as strings (`"primary"`, `"body"`).

---

## 2. Identity & deltas (the `id` contract)

Every component carries `id: string`. The `id` is:

- **Stable across renders.** Same logical button = same `id` every
  time the agent re-emits the tree.
- **The Patrol finder.** Tests use `find.byKey(ValueKey(id))`.
- **The delta target.** Rust→Flutter `Patch` deltas reference this
  `id`. Reusing an `id` for a different component will misroute deltas.
- **Author-supplied, not generated.** Pick descriptive ids:
  `save-btn`, `email-field`, `settings-tab`. Avoid uuids in dev;
  legibility helps the developer steer.

When the developer says "modify component X," the agent should
reuse `X`'s existing id and emit a tree with that id at the same
logical position.

---

## 3. Root envelope

```jsonc
{
  "type": "StacRoot",
  "schema_version": 1,
  "node": { /* one StacNode — usually a Scaffold */ }
}
```

- `schema_version` is `ushort`. Bump on breaking schema changes;
  current value is `1`.
- `node` is exactly one component. To render multiple top-level
  things, wrap in a `Scaffold` with `header` / `content` / `footer`.

---

## 4. Action vocabulary (`StacAction` union)

Actions are the only thing the renderer sends *back* to Rust. The
component fires the action; Rust runs Conduit; Rust emits a `Patch[]`
delta in response.

### `ActionUpdateState`

The default action for form-shaped components.

```jsonc
{
  "type": "ActionUpdateState",
  "key": "user.email",     // RDF predicate or KV path; Rust decides
  "value": "..."           // the new value (typed at the schema level)
}
```

### `ActionNavigate`

```jsonc
{
  "type": "ActionNavigate",
  "route": "/settings/profile",
  "args": { /* OpaqueJson; prefer typed Conduit messages instead */ }
}
```

### `ActionShowDialog`

```jsonc
{
  "type": "ActionShowDialog",
  "dialog": { /* a Dialog StacNode — see §6 */ }
}
```

### `ActionShowSheet`

```jsonc
{
  "type": "ActionShowSheet",
  "side": "right",   // top | bottom | left | right
  "sheet": { /* StacNode */ }
}
```

### `ActionShowToast`

```jsonc
{
  "type": "ActionShowToast",
  "toast": {
    "title": "Saved",
    "description": "Changes were synced.",
    "variant": "primary"   // primary | destructive
  }
}
```

### `ActionCustom`

Escape hatch for actions Conduit knows about that this skill file
doesn't cover. Emits a warning when the agent uses it; prefer adding
a typed action variant instead.

```jsonc
{
  "type": "ActionCustom",
  "name": "export_csv",
  "payload": { /* OpaqueJson */ }
}
```

---

## 5. Tokens

### 5.1 Color tokens (`ColorToken`)

Mirror Forui's `FColors` semantic vocabulary. Use these names anywhere
a color is referenced:

```
primary               primary_foreground
secondary             secondary_foreground
muted                 muted_foreground
destructive           destructive_foreground
error                 error_foreground
background            foreground
card                  border
barrier
```

The active palette (token → `Color`) is owned by the Flutter client
and switched without a Rust round-trip. The agent should never emit
hex values.

### 5.2 Typography tokens (`TypographyToken`)

```
xs3, xs2, xs, sm, md, lg, xl, xl2, xl3, xl4, xl5, xl6, xl7, xl8
```

Default body text resolves to `md`. Headers default to `xl`–`xl3`
depending on `Header.size` (§6).

### 5.3 Brightness (`Brightness`)

`light` | `dark`. Set on `Theme.brightness`; rarely overridden.

---

## 6. Component reference

Each entry: name, Forui mapping, purpose, fields, enums (if any),
example. Components are grouped by role.

### 6.1 Layout

#### `Theme`

Maps to `FTheme`. Wraps a subtree, scoping color/typography tokens.

| Field | Type | Required | Default | Notes |
|---|---|---|---|---|
| `id` | string | yes | — | |
| `child` | StacNode | yes | — | Subtree this theme governs |
| `brightness` | Brightness | no | `light` | |
| `border_radius` | float | no | inherited | Style override |
| `border_width` | float | no | inherited | Style override |
| `touch` | bool | no | `true` | Touch-density flag |

The token palette itself is **not** in the payload — it lives on
the client. `Theme` exposes structural overrides only.

```jsonc
{
  "type": "Theme",
  "id": "root-theme",
  "brightness": "dark",
  "border_radius": 8.0,
  "child": { /* Scaffold */ }
}
```

#### `Scaffold`

Maps to `FScaffold`. Top-level page frame: header / content / footer.

| Field | Type | Required | Default | Notes |
|---|---|---|---|---|
| `id` | string | yes | — | |
| `header` | StacNode | no | — | Usually a `Header` |
| `content` | StacNode | no | — | Main body |
| `footer` | StacNode | no | — | Persistent bottom area |
| `background_color` | ColorToken | no | inherited | Override scaffold bg |

```jsonc
{
  "type": "Scaffold",
  "id": "settings-scaffold",
  "header": { "type": "Header", "id": "settings-header", "title": "Settings" },
  "content": { "type": "Card", "id": "settings-card", "child": { /* ... */ } }
}
```

#### `Header`

Maps to `FHeader`. Page or section title bar.

| Field | Type | Required | Default | Notes |
|---|---|---|---|---|
| `id` | string | yes | — | |
| `title` | string | one of title/title_node | — | Plain text title |
| `title_node` | StacNode | one of title/title_node | — | Custom title widget |
| `suffixes` | [StacNode] | no | `[]` | Trailing widgets (icons/buttons) |
| `actions` | [StacNode] | no | `[]` | Action buttons (e.g., back) |

```jsonc
{
  "type": "Header",
  "id": "home-header",
  "title": "Home",
  "suffixes": [
    { "type": "Button", "id": "settings-btn", "variant": "ghost", "label": "⚙" }
  ]
}
```

#### `Divider`

Maps to `FDivider`. Visual separator.

| Field | Type | Required | Default | Notes |
|---|---|---|---|---|
| `id` | string | yes | — | |
| `axis` | Axis | no | `horizontal` | `horizontal` \| `vertical` |
| `color` | ColorToken | no | `border` | |
| `thickness` | float | no | `1.0` | Replaces former `width` |
| `padding` | EdgeInsets | no | — | See §7 |

### 6.2 Inputs

#### `Button`

Maps to `FButton`. Press-action button. The most-used component.

| Field | Type | Required | Default | Notes |
|---|---|---|---|---|
| `id` | string | yes | — | |
| `label` | string | one of label/child | — | Plain-text label |
| `child` | StacNode | one of label/child | — | Custom label widget |
| `prefix_icon` | StacNode | no | — | Leading slot |
| `suffix_icon` | StacNode | no | — | Trailing slot |
| `variant` | ButtonVariant | no | `primary` | |
| `size` | ButtonSize | no | `md` | |
| `on_press` | StacAction | no | — | Fires on tap |

**Enums:**
- `ButtonVariant`: `primary`, `secondary`, `outline`, `destructive`, `ghost`
- `ButtonSize`: `xs`, `sm`, `md`, `lg`

```jsonc
{
  "type": "Button",
  "id": "save-btn",
  "label": "Save",
  "variant": "primary",
  "on_press": { "type": "ActionUpdateState", "key": "form.submit", "value": true }
}
```

#### `TextField`

Maps to `FTextField`. Single-line text input.

| Field | Type | Required | Default | Notes |
|---|---|---|---|---|
| `id` | string | yes | — | |
| `label` | string | no | — | Above-field label |
| `description` | string | no | — | Help text below |
| `hint` | string | no | — | Placeholder |
| `error` | string | no | — | Error text (replaces description) |
| `prefix` | StacNode | no | — | Leading slot (icon) |
| `suffix` | StacNode | no | — | Trailing slot |
| `obscure_text` | bool | no | `false` | Password fields |
| `on_change` | StacAction | no | — | Fires on each edit |
| `on_submit` | StacAction | no | — | Fires on enter/submit |

**Form loop note.** Per the proposal, `on_change` should be debounced
or fired on blur, not on every keystroke. The renderer handles this;
the agent does not need to specify timing.

```jsonc
{
  "type": "TextField",
  "id": "email-field",
  "label": "Email",
  "hint": "you@example.com",
  "on_change": { "type": "ActionUpdateState", "key": "user.email", "value": "$value" }
}
```

> The literal `"$value"` is a placeholder convention for "the
> current field value." The renderer substitutes at action time.
> Subject to refinement when the action wire shape is finalized.

#### `Switch`

Maps to `FSwitch`. Boolean toggle.

| Field | Type | Required | Default | Notes |
|---|---|---|---|---|
| `id` | string | yes | — | |
| `label` | string | no | — | |
| `description` | string | no | — | |
| `value` | bool | no | `false` | |
| `enabled` | bool | no | `true` | |
| `on_change` | StacAction | no | — | |
| `semantic_label` | string | no | — | Accessibility label |

#### `Checkbox`

Maps to `FCheckbox`. Boolean checkbox with optional description.

| Field | Type | Required | Default | Notes |
|---|---|---|---|---|
| `id` | string | yes | — | |
| `label` | string | no | — | |
| `description` | string | no | — | |
| `error` | string | no | — | |
| `value` | bool | no | `false` | |
| `enabled` | bool | no | `true` | |
| `leading_label` | bool | no | `false` | Place label before the box |
| `on_change` | StacAction | no | — | |
| `semantic_label` | string | no | — | |

### 6.3 Presentation

#### `Card`

Maps to `FCard`. Titled container for grouped content.

| Field | Type | Required | Default | Notes |
|---|---|---|---|---|
| `id` | string | yes | — | |
| `title` | string | one of title/title_node | — | |
| `title_node` | StacNode | one of title/title_node | — | |
| `subtitle` | string | one of subtitle/subtitle_node | — | |
| `subtitle_node` | StacNode | one of subtitle/subtitle_node | — | |
| `child` | StacNode | no | — | Body content |

```jsonc
{
  "type": "Card",
  "id": "profile-card",
  "title": "Profile",
  "subtitle": "Manage your account",
  "child": { /* form fields */ }
}
```

### 6.4 Overlays

#### `Dialog`

Maps to `FDialog`. Modal dialog. Typically presented via
`ActionShowDialog`.

| Field | Type | Required | Default | Notes |
|---|---|---|---|---|
| `id` | string | yes | — | |
| `actions` | [StacNode] | yes | — | Action buttons (typically `Button`s) |
| `title` | string | one of title/title_node | — | |
| `title_node` | StacNode | one of title/title_node | — | |
| `body` | string | one of body/body_node | — | |
| `body_node` | StacNode | one of body/body_node | — | |
| `axis` | Axis | no | `vertical` | Stacking direction for actions |

```jsonc
{
  "type": "Dialog",
  "id": "delete-confirm",
  "title": "Delete account?",
  "body": "This cannot be undone.",
  "actions": [
    { "type": "Button", "id": "cancel-btn", "variant": "secondary", "label": "Cancel" },
    { "type": "Button", "id": "confirm-btn", "variant": "destructive", "label": "Delete",
      "on_press": { "type": "ActionUpdateState", "key": "account.delete", "value": true } }
  ]
}
```

### 6.5 TBD (5 more components for the first app)

Reserved slots; document as the app's needs surface. Strong candidates
from the harvest, in rough priority order:

- **`Slider`** — `FSlider`. Continuous numeric input.
- **`Tabs`** — `FTabs`. Multi-pane navigation within a screen.
- **`Tile` / `TileGroup`** — `FTile` / `FTileGroup`. List rows.
- **`SelectGroup`** — `FSelectGroup`. Radio-group / multi-select.
- **`Alert`** — `FAlert`. Inline status banner.
- **`Accordion`** — `FAccordion`. Collapsible sections.
- **`Calendar`** — `FCalendar`. Date picker.
- **`Avatar`** — `FAvatar`. User image.
- **`Badge`** — `FBadge`. Small status tag.
- **`Progress`** — `FProgress`. Loading/progress indicator.

Final 5 chosen by app needs. Don't add a component to the schema
without a real screen that uses it.

---

## 7. Shared types

### `EdgeInsets`

```jsonc
{ "top": 8, "right": 16, "bottom": 8, "left": 16 }
```

Or shorthand: `{ "all": 12 }` / `{ "vertical": 8, "horizontal": 16 }`.

### `Axis`

`horizontal` | `vertical`.

### `OpaqueJson`

Last-resort escape hatch carried as an embedded JSON string. Avoid;
prefer typed action variants and component fields. Used in
`ActionCustom.payload` and `ActionNavigate.args`.

---

## 8. Worked examples

### 8.1 Login screen

```jsonc
{
  "type": "StacRoot",
  "schema_version": 1,
  "node": {
    "type": "Scaffold",
    "id": "login-scaffold",
    "header": {
      "type": "Header",
      "id": "login-header",
      "title": "Sign in"
    },
    "content": {
      "type": "Card",
      "id": "login-card",
      "title": "Welcome back",
      "child": {
        "type": "TextField",
        "id": "email-field",
        "label": "Email",
        "hint": "you@example.com",
        "on_change": {
          "type": "ActionUpdateState",
          "key": "auth.email",
          "value": "$value"
        }
      }
    },
    "footer": {
      "type": "Button",
      "id": "signin-btn",
      "label": "Sign in",
      "variant": "primary",
      "on_press": {
        "type": "ActionUpdateState",
        "key": "auth.submit",
        "value": true
      }
    }
  }
}
```

### 8.2 Settings toggle with confirmation dialog

```jsonc
{
  "type": "Switch",
  "id": "notifications-switch",
  "label": "Notifications",
  "description": "Get pushes when peers sync.",
  "value": true,
  "on_change": {
    "type": "ActionShowDialog",
    "dialog": {
      "type": "Dialog",
      "id": "notifications-confirm",
      "title": "Disable notifications?",
      "body": "You'll miss sync events from your other devices.",
      "actions": [
        { "type": "Button", "id": "keep-btn", "variant": "secondary", "label": "Keep on" },
        { "type": "Button", "id": "off-btn", "variant": "destructive", "label": "Turn off",
          "on_press": { "type": "ActionUpdateState", "key": "settings.notifications", "value": false } }
      ]
    }
  }
}
```

---

## 9. Open items (not yet pinned)

These shape the agent's output and need a call before the schema is
codified. The agent should follow the conventions above for now and
flag any output that depends on these.

- **Field-value substitution syntax.** `"$value"` is a placeholder
  convention; the real wire shape may pass values via a different
  mechanism (e.g., the renderer attaches the controller value to the
  action at firing time, with no template in the payload).
- **Compound components.** Whether ZeroFlat's "compound" components
  are first-class schema entries or composed from primitives. Default
  assumption: composed; the schema stays atomic.
- **Form-validation surface.** `error` strings on `TextField` /
  `Checkbox` are written by Rust via deltas. Whether validation rules
  are in Conduit, in the schema, or both is not yet decided.
- **Hot-reload target path.** Where the agent writes the fbs/JSON
  payload during dev. Pinned by the dev tooling spec, not this file.
- **Final 5 components** (§6.5). Driven by the first app's screens.

---

## 10. Versioning this file

- Bump the file version when component fields, action variants, or
  token names change.
- Append-only when possible (matches the fbs schema-evolution rules).
- The `.fbs` schema is the binding contract; this file is the
  human-readable projection. If they disagree, the schema wins —
  but the disagreement is a bug in this file, fix it.
