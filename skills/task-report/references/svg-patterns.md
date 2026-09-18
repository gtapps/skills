# Inline SVG patterns for task-report diagrams

Read this only when a genuinely branching graph earns an SVG (a linear flow should be
a CSS flow strip instead — see SKILL.md). Everything here is self-contained and
theme-aware: the template styles `svg .box`, `svg .box.hot`, `svg .edge`, and
`svg text` with CSS variables, so use those classes and never hardcode fills.

## Ground rules

- Cap at ~15 nodes. Beyond that, the diagram needs prose, not more boxes.
- Mark changed nodes/edges with class `hot`; unchanged context stays default (gray).
  The diagram's job is "here is where the change sits", not "here is the system".
- Use a `viewBox` and `width="100%"` with a `max-width` style so it scales; never
  fixed pixel width.
- Grid-plan coordinates on paper first (rows of 70px, columns of 180px). Misaligned
  boxes read as sloppy and erode trust in the rest of the page.

## Skeleton

```html
<svg viewBox="0 0 720 220" width="100%" style="max-width:720px" role="img"
     aria-label="request flow through the changed auth middleware">
  <!-- defs: one arrowhead, reused by every edge -->
  <defs>
    <marker id="arr" viewBox="0 0 10 10" refX="9" refY="5"
            markerWidth="7" markerHeight="7" orient="auto-start-reverse">
      <path d="M0,0 L10,5 L0,10 z" fill="currentColor"/>
    </marker>
  </defs>

  <!-- box: rect + centered label -->
  <g>
    <rect class="box" x="20" y="20" width="150" height="44" rx="8"/>
    <text x="95" y="47" text-anchor="middle" font-size="13">client</text>
  </g>

  <!-- changed box -->
  <g>
    <rect class="box hot" x="240" y="20" width="150" height="44" rx="8"/>
    <text x="315" y="47" text-anchor="middle" font-size="13">auth middleware</text>
  </g>

  <!-- edge with arrowhead (marker inherits currentColor from .edge stroke) -->
  <path class="edge" d="M170,42 H240" marker-end="url(#arr)" stroke-width="1.5"
        color="currentColor"/>

  <!-- branch: use simple elbows, not curves -->
  <path class="edge" d="M390,42 H430 V110 H470" marker-end="url(#arr)"
        stroke-width="1.5" color="currentColor"/>
</svg>
```

## Recipes

- **Edge label**: `<text>` at the path midpoint, `font-size="11"`, offset 6px above
  the line. One or two words max.
- **Before → after structure** (refactors): prefer the template's `.ba` two-panel
  component (see SKILL.md) with one small SVG *per panel* — you get the labels,
  accent border, and responsive stacking for free, and each SVG stays simple.
  Only draw both states inside a single SVG when the two shapes must share
  coordinates (e.g., an arrow crossing from old to new); then separate them with a
  vertical rule (`<line class="edge" .../>`) and two `<text>` headers, moved nodes
  `hot` on the right.
- **Grouping** (a module boundary): a large rounded rect behind its children with
  `class="box"` and `opacity="0.5"`, label in the top-left corner, `font-size="11"`.
- **Dashed edge** for "no longer called": add `stroke-dasharray="4 3"` and say so in
  a caption under the SVG (`<div class="muted">dashed = removed path</div>`).

## Checklist before shipping the diagram

1. Every node label fits its box (13px font ≈ 7px/char — size rects accordingly).
2. `hot` marks exactly the changed elements, nothing else.
3. Render survives both themes (no literal colors anywhere).
4. The caption sentence under the SVG states what the operator should notice —
   a diagram that needs no caption usually needed no diagram.
