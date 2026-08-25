---
name: frontend-engineering
description: House conventions for writing frontend code — TypeScript by default with Zod schemas parsing every untrusted input, a default toolkit (React, TanStack Query with Suspense, shadcn/ui, Lucide, Flexoki), CSS built on design tokens, sensible units, small components under 100 lines with business logic extracted to plain modules and stateful behaviour to hooks, memoization left to the React Compiler, layered error boundaries, hand-rolled forms validated by a Zod schema against a touched-field set, readable URLs that carry view state, correct ARIA and keyboard accessibility, and behaviour-focused tests. Use this skill whenever implementing, refactoring, or reviewing any UI code, in any framework (React, Solid, Vue, Svelte, plain DOM), and whenever writing or changing stylesheets, building components, building or validating a form, wiring routing or filters, adding frontend tests, choosing a UI library or adding a dependency, fetching data from an API, handling loading or error states, typing or validating data that arrives from an API, URL, storage or message, or making an interface accessible — even when the request is just "add a button" or "fix this styling" and doesn't mention conventions at all.
---

# Frontend engineering

Conventions for UI code that stays editable by humans after an agent writes it.
Apply these in any framework; where syntax differs, the principle doesn't.

1. **Use the library** for components, icons, and anything with keyboard
   behaviour. Forms are the one exception — hand-roll them.
2. **Colours and repeated values are tokens.** One change point, not fifty.
3. **Components render; modules decide.** Business logic lives in plain
   TypeScript, not in components.
4. **Untrusted data is parsed, not asserted.** A cast is not validation.
5. **Use the native element** — it brings semantics, keyboard behaviour, and
   focus handling that ARIA otherwise reconstructs by hand.
6. **Test behaviour, not construction.** Tests coupled to implementation punish
   refactoring — exactly when tests should help.

---

## Default toolkit

| Need | Use |
|---|---|
| Language | **TypeScript** |
| Schemas & runtime validation | **Zod** |
| Data fetching | **TanStack Query** — or the framework equivalent / native loader |
| Components | **shadcn/ui** — or the framework port (`shadcn-solid`, `-vue`, `-svelte`) |
| Icons | **Lucide** |
| Colour palette | **Flexoki** |
| Forms | **Hand-rolled** against a Zod schema — see Forms |
| Package manager | **bun** — `bun install` / `bun add` / `bunx` |

Check what the project already depends on first — an existing choice wins.
shadcn/ui is copy-in: you own the component, and adopting it means adopting
Tailwind. Flexoki is a palette, not a design system — map its ramps to semantic
tokens once, never a raw ramp name in a rule.

### Reach for a maintained package first

The code you don't write is the code you don't debug, test, patch, or explain.
Before implementing anything that sounds like a solved problem — date handling,
currency formatting, CSV parsing, fuzzy search, keyboard shortcuts, uploads with
progress — look for the package. **Never hand-roll** a modal, combobox, date
picker, drag-and-drop, virtualised list, or focus trap; that's where
accessibility and keyboard bugs concentrate.

Judge a candidate on: released in the last year or so, issues being answered,
types shipped, usable licence, size proportionate to the job. The counterweight
is scope — a dependency for one ten-line function is a bad trade; the rule is
about *solved problems with hidden depth*. What you write yourself goes in a
plain module, so swapping in a package stays a one-file change. **Forms are the
standing exception.**

---

## Types and schemas

New frontend code is TypeScript — modules, config, and tests, not just
components. A project committed to something else keeps its language.

- No `any`. Use `unknown` at boundaries and narrow, or write the type.
- Don't reach for `as` to silence an error — a cast asserts something the
  compiler couldn't verify, and it's usually the compiler that's right.
- Type the domain: `type RunStatus = 'queued' | 'running' | 'failed'` beats
  `string` and makes exhaustive `switch` checking work.
- Infer locals; annotate exported signatures, where a wrong inference propagates
  silently.

### Zod for anything from an untrusted source

**Data crossing into the app from outside is `unknown` until a schema has parsed
it.** A TypeScript type asserts nothing about the bytes that arrived. Untrusted
means anything the app didn't construct itself: HTTP responses (including your
own API, which can be an older deploy), URL and route params, storage, cookies,
`postMessage`/WebSocket/SSE payloads, uploads, pasted content, client-delivered
config, third-party SDK callbacks.

```ts
const user = (await res.json()) as User;                    // ✗ a cast
export const User = z.object({ id: z.string().uuid() });    // ✓ a schema
export type User = z.infer<typeof User>;
```

- **Derive the type from the schema** with `z.infer`, never maintain both.
- **Parse at the boundary**, once, in the fetching or adapter module — not in a
  component, not repeatedly downstream. Past that line everything is trusted.
- **Schemas live with the module owning the boundary**, shared with the server
  where code is shared. A form schema is the server's schema.
- **`safeParse` where failure is expected and recoverable** — URL params, stale
  storage — handling the failure branch explicitly.
- **Validate, don't just shape-check**: `.email()`, `.uuid()`, `.min()`.
- `z.discriminatedUnion` for tagged payloads; better errors, clean narrowing.

Don't parse data the app built itself or props between your own components.
Validation failure is an error path with real UI.

---

## Data fetching

### TanStack Query, with Suspense

Use **TanStack Query** for reads rather than a bare `fetch` in an effect, and
**`useSuspenseQuery`** so boundaries render loading and error instead of
in-component status flags — `data` is then non-nullable, and the guards and the
union type that forced them disappear.

```tsx
<ErrorBoundary fallback={<ErrorMessage />}>
  <Suspense fallback={<ProfileSkeleton />}><Profile id={id} /></Suspense>
</ErrorBoundary>;

function Profile({ id }: { id: string }) {
  const { data: user } = useSuspenseQuery(userQuery(id));   // never undefined
  return <h1>{user.name}</h1>;
}
```

Scope the boundary to the region actually pending — a skeleton matching the
loaded layout beats a spinner that collapses the page. Every Suspense boundary
needs an error boundary above it, or a failed request becomes a fallback that
never resolves. Two caveats: **there is no `enabled`**, so conditional fetching
needs plain `useQuery` or a component that mounts only once its inputs exist;
and **sibling suspense queries waterfall**, so use `useSuspenseQueries` or give
each its own boundary. An existing choice wins — a project on SWR, Apollo, RTK
Query, or framework loaders keeps it.

### The fetcher is the boundary

A plain module function that checks the response, parses with Zod, and returns
typed data — testable without rendering. A schema failure throws and surfaces as
`error`, making a validation bug visible rather than a crash deep in a render.

```ts
export async function fetchUser(id: string): Promise<User> {
  const res = await fetch(`/api/users/${id}`);
  if (!res.ok) throw new Error(`Fetching user failed: ${res.status}`);
  return User.parse(await res.json());
}
```

### Keys are the cache

The key must contain everything the request varies by, as an array — resource
name first, params after. `['runs']` alone collides every filter combination on
one entry; `['runs', projectId, status, sort]` doesn't. The prefix gives
invalidation for free: `['runs']` matches every key beneath it. Filters and sort
belong in the URL, so derive the key from URL state and the cache follows
navigation.

Wrap each resource in a named hook so one place owns the key, fetcher, and
options; factoring those into a plain function (`userQuery(id)`) lets the same
definition serve `useQuery` and `prefetchQuery` on a loader or link hover.

### Handle every state

Loading, error, empty, and populated are four states. Under Suspense the first
two belong to the boundaries, leaving the component the other two — an empty
result needs its own copy, not a table with no rows. For writes use
`useMutation`, then `invalidateQueries` on affected keys in `onSuccess`.
Optimistic updates only where failure rolls back honestly — `onMutate` always
needs a matching `onError` restoring its snapshot. Don't disable revalidation to
quieten a bug: a long `staleTime` is right for static data and wrong as a fix
for a key that changes when it shouldn't.

### Error boundaries come in layers

Every app needs **a catch-all boundary at the root** and **a boundary around
each page** inside the persistent layout. Without the per-page one, an error in
one view unmounts the whole tree and the user loses the nav.

```tsx
<ErrorBoundary fallback={<FullPageError />}>       {/* catch-all: last resort */}
  <AppShell>                                        {/* nav, sidebar, header */}
    <ErrorBoundary key={pathname} fallback={<PageError />}>
      <Suspense fallback={<PageSkeleton />}><Route /></Suspense>
    </ErrorBoundary>
  </AppShell>
</ErrorBoundary>
```

Key the page boundary on the route — a boundary stays tripped until something
resets it, so without the key a user navigating away still sees the error. The
page boundary reports what failed and offers a retry with nav intact; the
catch-all can't assume any of the app works, so it renders standalone markup and
reports to your error-tracking service. Add narrower boundaries wherever a
widget can fail independently. Error boundaries don't catch event-handler or
async errors — a `useMutation` rejection needs its own toast or inline message.

---

## CSS

Read the project's tokens and one existing component before writing any CSS.
Never invent a palette, spacing scale, or type scale that already has an answer.

### Tokens where they earn their place

Over-tokenising is its own mess. The question worth asking: would someone
changing the design want to change this in one place, or is it a detail of this
component alone?

**Always a token:** colours (no exceptions — this is what theming runs on);
anything already on a project scale (`--space-3`, not `0.75rem`); values
repeating three or more times; values differing between themes.

**Fine as a literal:** one-off sizing (`max-inline-size: 42rem`, a `3px` optical
offset); structural values (`z-index: 1`, `flex: 0 0 auto`, `100%`, `1fr`);
hairlines and focus outlines.

Where a value **varies by variant or state**, hoist it to a local token named
`--{component}-{property}` and let variants reassign it rather than restate
properties:

```css
.btn {
  --btn-bg: var(--primary);
  --btn-height: 2.25rem;
  background: var(--btn-bg);
  block-size: var(--btn-height);
  padding-inline: var(--space-3);   /* same in every variant — no indirection */
}
.btn[data-variant="ghost"] { --btn-bg: transparent; }
.btn[data-size="sm"]       { --btn-height: 2rem; }
```

Variants stay one line, the cascade can't fight itself, and a one-off override
is `style="--btn-bg: …"` at the call site. A local token used once and never
reassigned is just a longer way to write the value. Global and app-domain
decisions (`--muted`, `--state-error`) go in the root token block,
single-component values in the component rule; a global token used by exactly
one component should be a component token. Every colour token needs a light and
a dark value.

### Layers, selectors, variants

Declare the order once and never write CSS outside a layer — `@layer reset,
tokens, base, layout, components, utilities;`. `tokens` paints nothing; `layout`
handles shells and grids without colour. Layers make specificity a non-issue,
which is most of why `!important` exists.

Max two levels of nesting, `&` explicit. No ID selectors, no `!important`, no
element selectors in `components`. Name internal parts `.card__header`. Prefer
`@container` over media queries for component-level responsiveness. Variants and
state are data attributes — `.btn[data-variant="destructive"]`, not
`.btn-destructive`; it matches what headless libraries expose and avoids
conditional class-string building. Dark mode is token overrides only — `.dark {
--card: oklch(0.205 0 0); }`, never `.dark .card { … }`; a component needing a
theme-specific rule is missing a token. Use `oklch()` for new colours, deriving
shades rather than adding tokens: `oklch(from var(--btn-bg) calc(l - 0.05) c h)`.

### Units

| Use | For | Why |
|---|---|---|
| `rem` | Almost everything — spacing, radii, type, sizing | Scales with the user's font size; `px` ignores it |
| `ch` | Max width of body-text containers | Line length is typographic: `65ch` holds a readable measure |
| `fr` | Grid tracks | Expresses proportion, absorbs the remainder without `calc()` |
| `dvh` / `vw` | Page-level layout only | `dvh` survives mobile browser chrome |
| `%` | Filling a parent | Relative to the container |
| `em` | Values tracking local font size | Compounds when nested, so use shallowly |
| `px` | Hairlines and focus outlines | These genuinely shouldn't scale |

Define scales in `rem` once so component code rarely picks a unit, and prefer
logical properties (`inline-size`, `padding-inline`) — they cost nothing and
work in right-to-left locales.

Use the shorthand when setting the whole thing (`padding`, `border`, `gap`,
`inset`, `flex`). The caution: a shorthand resets every sub-property it covers,
including omitted ones — `background: var(--accent)` on `:hover` silently drops
`background-image`, and the same goes for `font` and `transition: all`. **Define
with shorthands; override with longhands.** One global stylesheet until roughly
1,000 lines, then split by module (`tokens.css`, `base.css`, `components.css`) —
not per-component CSS modules.

---

## Components

### Components render; modules decide

**Keep business logic out of components.** Pricing, validation, permissions,
parsing, date and currency handling, sorting, filtering, state machines — all of
it belongs in plain TypeScript modules importing nothing from the framework.
Logic in a component can only be tested by rendering it and gets rewritten when
the framework changes.

A component may keep logic genuinely *about* the UI: which panel is open,
whether a tooltip was dismissed, focus and animation state. Signals you've
crossed the line: a derived-value calculation more than a few lines, branching
on domain conditions, or a component you can't describe without explaining a
business rule.

### One responsibility, under 100 lines

Describable in one sentence with no "and". Symptoms of too much: section
comments separating its parts, a prop affecting only one branch, or both
fetching data and styling it.

**100 lines is the ceiling.** Past it the excess is almost always stateful
behaviour rather than markup — interlocking `useState` calls, an effect
coordinating them, handlers operating on them. Extract that into a custom hook,
leaving the component as JSX plus a call to it:

```tsx
function DataTable({ rows }: Props) {
  const { selected, toggle, onKeyDown } = useTableSelection(rows);
  return <table onKeyDown={onKeyDown}>{/* markup only */}</table>;
}
```

A hook is for *stateful* behaviour — logic touching neither state nor the
framework belongs in a plain module, which is cheaper still. A long component
that's one flat run of markup isn't a hook problem; split it into components.

### Structure

**Separate fetching from presentation.** Containers fetch and pass data down;
presentational components take props and render. The container calls a
per-resource query hook and passes loaded `data` down, with Suspense and error
boundaries above — so the presentational half never sees a loading flag.

**Wrappers stay thin.** A wrapper around a headless primitive adds a class name
and passes props through; the moment it grows a conditional it's a feature
component, so move it out of the shared directory.

**Keep state close to where it's used** — lift only to the nearest common
ancestor that needs it. State worth returning to belongs in the URL.

**Compose, don't configure** — five boolean props is thirty-two states, most
untested and some nonsensical.

```jsx
/* ✗ */ <Card title="Run" showFooter footerAction="retry" collapsible />
/* ✓ */ <Card><CardHeader>Run</CardHeader><CardFooter>…</CardFooter></Card>
```

### Let the React Compiler memoize

**Don't write `React.memo`, `useMemo`, or `useCallback` in new code.** The
compiler memoizes automatically and more precisely than hand-written dependency
arrays. Enable it in the build config and add `eslint-plugin-react-hooks` so its
rules flag code it can't safely optimize; bail-outs are almost always a Rules of
React violation (mutating props or state, reading a ref during render) — fix the
violation, don't add memoization back.

Three narrow cases still justify it by hand: a **measured** expensive
computation (the compiler memoizes on identity, not cost); a value whose
identity matters for **correctness**, like an effect dependency that would
otherwise refire a request; and `memo` on a leaf under a hot parent you can't
change, with a profile behind it. Leave existing memoization alone unless you're
already changing that code; without the compiler the old rules still apply.

---

## Forms

**Hand-roll forms** — the one documented exception to "reach for a maintained
package". A form library's value is its validation engine and state store; a Zod
schema provides the first, and `useState` plus a touched-field set the second in
about forty lines. Existing projects keep what they have.

One Zod schema owns the rules, shared with the server so they can't drift.
Cross-field rules use `.refine()` with a `path` anchoring the error to a real
field. State is `values`, `errors`, and **a set of touched field names**.

### Don't validate a field until it's been touched

A field the user hasn't reached yet is not yet wrong — validating on mount or on
first keystroke puts an error under an input they're two characters into. Add
the field to `touchedFieldSet` **on blur**, and show errors only for fields in
that set:

- **On blur** — mark touched, then validate. First feedback on leaving a field.
- **On change** — validate too, but the touched gate means it only *shows* for a
  field already blurred. A field being corrected updates live; one being filled
  for the first time stays quiet.
- **On submit** — validate the whole form, mark every field touched, reveal
  everything. Nothing hides because it was never visited.

```ts
function onChange(name: Field, value: string) {
  const next = { ...values, [name]: value };
  setValues(next);
  validateFields(fieldsToValidate(name), next);  // validate `next`, not `values`
}

function onSubmit(e: SubmitEvent) {
  e.preventDefault();
  const result = Checkout.safeParse(values);
  setTouchedFieldSet(new Set(FIELDS));           // reveal every error
  if (!result.success) return setErrors(allMessages(result.error));
  submit(result.data);                            // parsed and typed
}
```

### Fields validated together

Some rules span fields: card expiry month and year, password and confirmation,
start and end date. **Run the combined rule when any participating field changes
or blurs**, via a field→group map (`fieldsToValidate` above). Otherwise the user
corrects the year, and the "expiry date has passed" error sits under the month
where nothing they do clears it. Show a group error once, anchored to the
group's first field via the `refine` path, and display it when **any** member
has been touched — otherwise the message stays hidden while the user corrects
its partner.

### Prefer native elements

Use `<input>`, `<select>`, `<textarea>`, `<button>` styled with CSS unless they
genuinely can't meet the requirement — they bring keyboard behaviour, form
association, autofill, mobile keyboards, and screen-reader support that custom
controls rebuild incompletely, and `type="email"`, `inputmode`, `autocomplete`,
and `required` do real work. Reach for a headless primitive only when the
requirement is beyond a native control — a combobox with async search, a
multi-select with tokens, a date range picker — where the library rule
reasserts itself: don't hand-roll *those*.

Bind errors so they're announced, not just coloured — `aria-invalid` plus
`aria-describedby` pointing at the message element, and a real `<label>`. On a
failed submit, move focus to the first invalid field.

All of this is stateful behaviour, so it belongs in `useForm(schema, initial)`
returning `values`, `errors`, `touchedFieldSet`, and handlers. The component
reads `errors[name] && touchedFieldSet.has(name)`.

---

## URLs are state

If a state is worth returning to, it belongs in the URL. Reloading, sharing a
link, or pressing back should land the user where they were.

**In the URL:** route and resource, filters, sort, pagination, search query,
active tab, which detail item is open, date range. **Not in the URL:** transient
interface state — an open dropdown, hover, focus, scroll position, an unsaved
draft, a toast. Never secrets, tokens, or personal data; they leak through
referrers, logs, history, and shared links.

```
✗  /r?v=2&id=f3a91c&t=1&s=3
✓  /runs/f3a91c/logs?status=failed&sort=-started
```

Plural nouns for collections, kebab-case for multi-word segments, meaningful ids
over opaque indices, parameter names that read as words. Omit a parameter at its
default value so equivalent states share one URL. Changing a filter, sort, or
tab updates the URL immediately. **Replace** for
high-frequency or refining changes — typing in a search box, dragging a slider —
or back undoes one keystroke at a time. **Push** when back should undo the
change: opening a detail view, switching tab, applying a filter.

The URL is the source of truth: derive state from it rather than copying it into
local state and syncing both ways, which is where back-button bugs and stale
filters come from. Deep links must work on first load, without an intermediate
default state flashing first.

---

## Accessibility

The first rule of ARIA is not to use ARIA. Native elements bring roles, keyboard
behaviour, and focus management already correct — a `<div class="btn">` needs
role, tabindex, Enter and Space handlers, focus styling, and disabled semantics,
all easy to get wrong. Use `<button>`, `<a href>`, `<ul>`, `<nav>`, `<main>`,
`<dialog>`, `<details>`, real form controls; add ARIA only where no native
equivalent exists — tabs, comboboxes, trees — preferring a tested headless
library for those.

Every interactive element needs an accessible name: visible text is the best
one, and a bare `<button><CloseIcon /></button>` announces only as "button", so
it needs `aria-label` with the icon `aria-hidden="true"`. Inputs need a real
`<label>` — `placeholder` disappears on focus.

| Mistake | Consequence |
|---|---|
| `role` contradicting the element | Announced role and behaviour disagree |
| `aria-label` on a roleless `<div>`/`<span>` | Silently ignored |
| `aria-hidden` on something focusable | Keyboard-reachable but invisible |
| `role="button"` without `tabindex` and key handlers | Unusable by keyboard |
| `aria-labelledby` pointing at a missing id | No name at all |
| ARIA state never updated | Confidently wrong — worse than absent |

If you add an ARIA attribute, something must keep it truthful. Express dynamic
state through ARIA, not class names alone — `aria-expanded`/`aria-controls` on
disclosures, `aria-current="page"` on nav, `aria-invalid` plus
`aria-describedby` on fields. Prefer `hidden` over `aria-hidden`; it removes the
element from the accessibility tree and tab order together.

Everything actionable works by keyboard alone. Style `:focus-visible`; never
delete `outline` without replacing it. Preserve DOM order; avoid positive
`tabindex`. Dialogs trap focus, close on `Escape`, restore focus on close. Move
focus deliberately after route changes and destructive actions. Content
appearing without user action needs a live region already in the DOM —
`role="status" aria-live="polite"` for routine updates, `role="alert"` for
errors, since it interrupts.

Contrast at least 4.5:1 for body text, 3:1 for interactive boundaries. Never
carry meaning by colour alone. Respect `prefers-reduced-motion`. Touch targets
at least 24×24px. Layout survives 200% zoom and a 320px viewport.

---

## Testing

**Tests should survive a refactor and fail on a regression.** A test that breaks
on a rename, or passes while a user-facing behaviour is broken, is worse than no
test.

| Don't test | Do test |
|---|---|
| Internal state values | What the user sees after an interaction |
| Which internal functions ran | Which network calls were made |
| Component instance internals | Rendered output |
| CSS class names | Visible state and accessible attributes |

```js
/* ✗ */ expect(wrapper.state('isOpen')).toBe(true);
/* ✓ */ await user.click(screen.getByRole('button', { name: 'Filters' }));
        expect(screen.getByRole('dialog', { name: 'Filters' })).toBeVisible();
```

Query by role and accessible name first, then label text, then visible text. A
test id is a last resort and a signal the markup needs work — an element a test
can't address semantically usually can't be reached by a screen reader either.

Per component: renders with realistic props, responds to interaction, reflects
loading/empty/error/populated states, operable by keyboard with correct roles
and names. Avoid whole-component snapshots — they fail on cosmetic changes and
get regenerated unread. Because logic lives in plain modules, test it there,
weighting tests by consequence: a currency rounding rule deserves far more than
a tooltip.

**Cover happy and sad paths.** Sad paths are where bugs live and where generated
code is weakest, because the prompt described the happy path. Ask what happens
when: the request fails or times out; data is empty or `null`; input is
malformed; the user lacks permission; the user double-submits; a response
arrives after unmount. Name tests as behaviour in domain language — `it('shows
the results once the search completes')`, not `it('sets isLoading to false')`.

---

## Before finishing

- [ ] Libraries used for components and icons; any package added is maintained
      and typed. Forms are the exception — hand-rolled against a Zod schema.
- [ ] Fields validate on blur and change, but errors show only for fields in
      `touchedFieldSet`; submit validates all and reveals every error.
- [ ] Cross-field rules re-run when any participating field changes or blurs,
      and show once any member is touched.
- [ ] Native form controls unless the requirement needs more; errors bound with
      `aria-invalid` / `aria-describedby`; focus moves to the first invalid field.
- [ ] No hardcoded colours; scale values used where a scale exists; repeated
      values (3+) promoted to tokens, one-off sizes left local.
- [ ] New tokens have light and dark values; variants use `data-*` and reassign
      local tokens; no theme-specific selectors outside the token block.
- [ ] `rem` for sizing, `ch` for text width, `fr` for grids, `px` only for
      hairlines; logical properties throughout.
- [ ] Shorthands when defining; longhands when overriding one sub-property.
- [ ] All CSS inside a layer; nesting two levels or fewer; no `!important`.
- [ ] TypeScript unless the project requires otherwise; no `any`, no casts
      standing in for validation.
- [ ] Every untrusted input parsed by a Zod schema at the boundary, types
      derived via `z.infer`.
- [ ] Reads go through TanStack Query, not a bare `fetch` in an effect; keys
      include everything the request varies by.
- [ ] Reads use `useSuspenseQuery` with a `<Suspense>` fallback scoped to the
      pending region and an error boundary above it; siblings don't waterfall.
- [ ] Loading, error, empty, and populated each rendered deliberately; errors
      offer a retry where that makes sense.
- [ ] A catch-all error boundary at the root and a per-page boundary keyed on
      route inside the layout, so a page crash leaves the nav usable.
- [ ] Business logic in plain modules with no framework imports.
- [ ] Each component has one responsibility and is under 100 lines; stateful
      behaviour past that is extracted into a hook.
- [ ] No new `memo`, `useMemo`, or `useCallback` — any hand-written memoization
      has a measurement or correctness reason.
- [ ] Filters, sort, tabs, pagination in the URL and surviving a reload; URL read
      as source of truth, not mirrored; no secrets or personal data in it.
- [ ] Native elements wherever one exists; ARIA only fills real gaps and is kept
      in sync; nothing focusable is `aria-hidden`.
- [ ] Every interactive element has an accessible name; decorative icons hidden.
- [ ] Whole flow works by keyboard; `:focus-visible` styled, not removed.
- [ ] Async and error messages land in a pre-existing live region.
- [ ] Contrast meets 4.5:1; meaning never carried by colour alone.
- [ ] Tests query by role and name; none assert on internal state or classes.
