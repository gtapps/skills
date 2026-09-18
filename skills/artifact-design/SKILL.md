---
name: artifact-design
description: "Design self-contained HTML reports, dashboards, and shareable pages. Excludes routine prose answers and ordinary Markdown edits."
---

Approach this as the design lead at a small studio known for their versatility, giving every client a visual identity pitched at the treatment the task actually calls for. Make deliberate choices about palette, typography, and layout that are specific to this subject, and avoid templated designs.

## Read the request first

Choose the format and visual treatment from the requested deliverable and its destination. Respect an explicit format. Use Markdown for prose documents when it fits; use HTML when layout or interaction helps the reader.

Many requests call for a more utilitarian treatment: a plan, a memo, a demo. Make it polished: include real typographic hierarchy, considered spacing, and a proper palette, but avoid over-designing. Most pages do not need a flashy, gigantic hero. Keep flourishes tasteful and limited.

Some requests call for an editorial treatment: a landing page, a game, an app or tool they'll keep or share.

Use only the design work the deliverable needs; a routine prose answer does not need a page.

Fundamentals below apply to everything. The editorial process after that runs only when the read above says so.

## Fundamentals for every artifact

**Honor what's already there** Look for an existing design system first, CLAUDE.md, a tokens or theme file, existing component styles. When one exists, apply it; everything below fills gaps and never overrides. Precedence is always: the user's own words, then the project's existing system, then your choices.

**Ground it in the subject.** If the subject isn't already clear, pin it: one concrete subject, its audience, and the page's single job. The subject's own world, its materials, instruments, vernacular, is where distinctive choices come from. Build with real content throughout, never lorem.

**Pair typefaces** Typography carries the page even when the page isn't about typography. The page has to stand alone as a single file, so don't link a webfont URL and risk a silent fallback. Instead inline the face as a @font-face data URI. Keep running text near 65 characters wide; set a type scale and stay on it; give headings `text-wrap: balance`, body text room to breathe, and uppercase labels a touch of letter-spacing.

**Choose neutrals, don't default to them.** A pure mid-grey reads as unconsidered; a grey with a slight hue bias toward the page's accent reads as chosen. Pure white and near-black are fine grounds when they suit the subject, the point is that the neutral was picked, not inherited.

**Design both themes.** The page renders in whatever theme the reader's OS is set to, so `prefers-color-scheme` is what separates light from dark. Structure the CSS token-level: the bare `:root` block defines the complete light palette (for a deliberately dark-first design, swap light and dark consistently through this whole pattern), and `@media (prefers-color-scheme: dark)` redefines only the tokens. Style components through the tokens, never directly inside a media block, a color whose only definition sits behind the media query never applies in the light state, and the page renders one theme's text on the other theme's ground. Two more rules keep each theme resolving as a set: `body` must set an explicit `background` from a token, a transparent body silently borrows whatever ground it is dropped onto; and every element that sets a color takes it from the same token set as the surface behind it, never a literal that only works in one theme. Before shipping, scan the stylesheet for any color declared only inside a media block, that is the classic unreadable-page bug. Give the second theme the same care as the first, don't naively invert; keep contrast legible and the accent working on both grounds. A design that deliberately commits to one visual world (a neon arcade screen, a letterpress invitation) may stay single-theme, then skip the media query entirely but still paint the background and every color explicitly, so the page holds on any ground; make it a choice, not an omission.

**Let layout do the spacing.** Lay out sibling groups with flex or grid and `gap`, not per-element margins that silently collapse or double. Wide content, tables, code, diagrams, gets `overflow-x: auto` on its own container so the page body never scrolls sideways. Reach for `font-variant-numeric: tabular-nums` wherever digits line up in columns.

**Avoid AI-generated design** AI-generated design currently clusters around a few looks: warm cream (#F4F1EA) with a serif display and terracotta accent; near-black with a lone acid-green or vermilion pop; broadsheet hairline rules with dense columns; a purple-to-blue gradient hero on white; Inter or Space Grotesk as the "safe" face; emoji as section markers; everything centered; `rounded-lg` everywhere; accent bar/rail on rounded cards. Where the user pins down a visual direction, follow it exactly, their words always win, including when they ask for one of these looks. Where nothing is specified, don't spend that freedom on one of these defaults.

**Build cleanly** Be cognizant of overlapping elements, cascade collisions, silent font fallbacks; visual bugs hide in the gap between source and output. Close every non-void element, double-quote attributes, give keyboard focus a visible state, respect `prefers-reduced-motion`. For generative or decorative graphics, reach for Canvas or WebGL rather than hand-authoring long SVG path data.

**CSS rules** When writing the CSS, watch your selector specificities. It is easy to generate classes that cancel each other out, a type-based selector like `.section` fighting an element-based one like `.cta` over padding and margins between sections. Structure the cascade so it doesn't silently undo your spacing.

**Writing the copy** Words are design material, not decoration. Write from the user's side of the screen, name things by what people recognize, not how the system is built (a person manages *notifications*, not *webhook config*). Active voice; a control says exactly what happens ("Publish", then a toast that says "Published"). Errors explain what went wrong and how to fix it, no apologies, no vagueness. Specific beats clever.

**Name the page like a product, not a caption.** The `<title>` is the page's name in the browser tab, and it sets the reader's first impression of care. Give the page a real name: a short noun phrase, typically two to four words, specific to the subject, or, for a page that exists to answer one question, that question itself, which is then the page's name. Stop at the name, a title that carries its own explainer after a dash or colon reads as generated filler. The name must also identify the page among many: it sits beside dozens of other files, and a generic category label that could sit on any of them fails as a name just as surely as an appended explainer. When a candidate title pairs the name with a generic word, a greeting, a category, a page-type label, the name is the half to keep; a trim that drops the identity and keeps the generic word produces exactly the title that could sit on any page. And the rule removes explainers, it does not impose brevity: a multi-word title that already reads as one specific name is finished, and shortening it further only makes it generic. A one-sentence subtitle under the title is where the explanation belongs.

**Structure is information** Structural devices, numbering, eyebrows, dividers, labels, should encode something true about the content, not decorate it. Many generic designs use numbered markers (01 / 02 / 03), but that's only appropriate if the content actually is a sequence - like a real process or a typed timeline where order carries information the reader needs. Question if choices like numbered markers actually make sense before incorporating them.

**When it's a UI, not a document** A dashboard or tool is scanned and operated, not read top-to-bottom, so the craft shifts from typography to information design. Surface the summary before the detail; encode state in form as well as number, a pill, a chip, a severity stripe, so what needs attention reads at a glance. Semantic color (good / warning / critical) is separate from the accent hue and doesn't count as your accent. Give sparklines and charts the same care as type: an area fill, a faint grid, an emphasized endpoint. What's interactive should look interactive.

**When adding charts or diagrams** The craft shifts from identity to honesty, pick the form the data's shape calls for, keep encodings from exaggerating, title the finding rather than the axes. Load the `$dataviz` skill for the specifics; this skill continues to govern the page the chart sits in. For a mechanism diagram rather than a chart, load `$artifact-diagramming`.

## Process

Before writing code, sketch a short design plan, a compact token system with color, type, and layout:
- **Color**: describe the palette as 4–6 named hex values.
- **Type**: typefaces for 2+ roles, a characterful display face used with restraint, a complementary body face, and a utility face for captions or data if needed.
- **Layout**: a layout concept in one or two sentences.

Then build, following the plan and deriving every color and type decision from it.

## When the request is editorial

The stance shifts: the client has already rejected proposals that felt templated, and is paying for a distinctive point of view. Make opinionated calls, and take one real aesthetic risk where it serves the work.

Review the design plan against the subject before building: if any part of it reads like the generic default you would produce for any similar page, revise that part, and note what you changed and why. Only after you've confirmed the plan's uniqueness do you write the code, following the revised plan exactly.

**Principles** 

- The hero is a thesis: open with the most characteristic thing in the subject's world, headline, image, live demo, interactive moment. 
- Typography carries the personality of the page. Pair the display and body faces deliberately, not the same families you would reach for on any other project, and set a clear type scale with intentional weights, widths, and spacing. Make the type treatment itself a memorable part of the design, not a neutral delivery vehicle for the content. 
- Leverage motion deliberately. Think about where and if animation can serve the subject: a page-load sequence, a scroll-triggered reveal, hover micro-interactions, ambient atmosphere. An orchestrated moment usually lands harder than scattered effects; choose what the direction calls for. However, sometimes less is more, and extra animation contributes to the feeling that the design is AI-generated. 
- Match complexity to the vision. Maximalist directions need elaborate execution; minimal directions need precision in spacing, type, and detail. Elegance is executing the chosen vision well.
- Spend your boldness in one place; keep everything around it quiet. If the accent fights the ground, shift it toward analogous or drop saturation rather than replacing it.

## Starting points

Four page templates ship in this skill's `assets/` directory, each with
`<!-- SLOT: ... -->` markers describing what goes where:

| Template | For |
|---|---|
| `assets/report.template.html` | Long-form prose read top-to-bottom, report, memo, spec, design doc |
| `assets/dashboard.template.html` | KPI tiles, a primary time-series chart, a breakdown table |
| `assets/data-table.template.html` | A sortable, filterable table for browsing rows |
| `assets/explainer.template.html` | A step-by-step conceptual walkthrough |

Copy one into the workspace as a starting point, replace every slot with real
content, and delete the slot comments and their placeholder text. The templates
set a visual foundation, they do not fix the final structure. Everything above
still governs; a filled-in template that skipped the design pass reads like one.
Skip them entirely when the page wants its own composition.
