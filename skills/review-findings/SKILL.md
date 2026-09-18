---
name: review-findings
description: "Verify external review findings against current code or runtime evidence, then apply only confirmed corrections when requested."
---

# Review Findings

Treat each finding as a hypothesis. Resolve it from the current code and runtime evidence, not the reviewer's quotation or line numbers.

## Triage

1. Resolve the source. A bare #N refers to PR N in the current repository; the findings set is every review comment on it, bot and human, excluding resolved threads.
2. Enumerate and deduplicate distinct findings.
3. Check whether the review targeted an older branch or commit. Locate moved code by symbol.
4. Order correctness, data-loss, and security claims before lower-stakes findings.
5. Cover the requested findings set. For a large set, report progress by group; ask only if the intended scope is unclear.

## Verify

For more than three independent findings, use read-only subagents in parallel when collaboration tools and capacity are available. Group findings that share files or behavior. This skill explicitly authorizes that delegation. If agents are unavailable, verify serially.

For each finding:

1. Locate the cited code or symbol.
2. Read the current file. Do not trust quoted snippets.
3. Compare the claim with what the code actually does.
4. Probe the real behavior when static reading cannot settle it.
5. Evaluate the proposed fix separately from the claimed problem.

Classify it:

- Confirmed: the claim is accurate and the fix or its intent improves the code.
- Refuted: the claim or proposed fix is wrong.
- Partial: a real problem exists but the framing or fix is wrong.
- Needs investigation: the remaining uncertainty depends on unavailable evidence; name exactly what would resolve it.

## Output

Render one block per finding:

    ## Finding N: <title> [high|med|low]
    **Claim:** <one line>
    **Evidence:** <path:line or command and what it proved>
    **Verdict:** Confirmed | Refuted | Partial | Needs investigation
    **Action:** <specific action or none>

Then summarize only Confirmed and Partial actions, highest severity first. Keep Refuted findings in their blocks so the user can see why they were rejected.

## Act only when requested

- Default: report only.
- In Plan Mode: revise the plan only when the user asks; include only Confirmed actions and the corrected portion of Partial actions. Return a complete replacement plan when the interface requires one.
- In execution mode with "verify then fix": implement Confirmed actions and corrected Partial actions only.
- Never apply Refuted findings or unrelated improvements.

Evidence must cite inspected code or observed behavior. A paraphrase of the review is not evidence.

