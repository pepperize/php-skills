---
name: php-solid-review
description: Reviews and guides PHP code using pragmatic engineering design principles, including SOLID, DRY, KISS, composition, encapsulation, collaboration, and simplicity. Use for explicit code, architecture, or design reviews and for self-reviewing non-trivial PHP implementations, refactors, classes, services, ports, adapters, factories, policies, or collaborators.
---

# PHP Design Review

## Scope

- Treat design principles as review heuristics, not mandatory findings.
- Prefer maintainable, testable, intention-revealing, simple local designs over pattern-heavy code, theoretical purity, or hypothetical flexibility.
- Report a principle only when the code provides evidence of a material design risk. Do not emit a checklist of principles, manufacture violations, or turn minor style preferences into design findings.
- Apply project conventions and more specific PHP skills first when they are relevant.

## Skill Precedence

- For tests, use `php-testing-style`. This skill must not override its rules for test naming, mocking style, unit versus integration boundaries, assertions, layout, or verification scope.
- For readable PHP naming, guard clauses, factories, utilities, nullable collections, and test-only production code, use `php-readable-code`.
- For domain-sensitive behavior, identifiers, persistence shape, or invariants, use `php-domain-clarification` before proposing or coding changes when rules are unclear.
- Use `php-clean-architecture` and `php-ddd-architecture` only when project instructions explicitly state those architectures; do not move code across such boundaries as incidental cleanup.

## Principle Reference

Before an explicit code, architecture, or design review, or before self-reviewing a non-trivial implementation, read [engineering-principles.md](references/engineering-principles.md). It defines the canonical names, intent, review signals, counterexamples, examples, and relationships for:

- DRY, KISS, FCoI, IOSP, and Single Level of Abstraction;
- SRP, SoC, ISP, DIP, LSP, and OCP;
- Principle of Least Astonishment and Information Hiding Principle;
- Tell, Don't Ask and LoD;
- Implementation Reflects Design and YAGNI.

Use the reference to select relevant questions, not as a list to reproduce in the review.

## Review Workflow

1. Identify the required behavior, actual change, responsibilities, contracts, collaborators, and architectural boundaries.
2. Trace the important paths through the code. Look for concrete change, comprehension, coupling, substitution, encapsulation, and testability risks.
3. Select only principles that explain a material observed risk. Similar code, a concrete dependency, inheritance, or a conditional is not a violation by itself.
4. State the consequence in this codebase. If no credible consequence exists, omit the finding.
5. Recommend the smallest practical improvement that addresses the present risk while preserving behavior.
6. Challenge the proposed improvement with KISS and YAGNI. Avoid replacing a local problem with speculative abstractions, excessive fragmentation, or indirection.
7. Verify with the narrowest credible test scope, following `php-testing-style`.

When overlapping principles could describe the same problem, use the name that most precisely identifies the risk:

- use SRP for independently changing responsibilities concentrated in one unit, and SoC for entangled kinds of policy or mechanism such as HTTP, persistence, business rules, and presentation;
- use DRY when duplicated knowledge creates multiple authorities that must stay synchronized, and OCP when demonstrated recurring variants force stable dispatch or policy code to change for each addition;
- use Information Hiding Principle when representation or mutable internals escape their owner, Tell, Don't Ask when a caller queries state to make a decision the object should own, and LoD when a caller depends on a collaborator's internal object graph;
- use Single Level of Abstraction when high-level intent is obscured by low-level detail, and IOSP when decisions or transformations are interleaved with collaborator coordination and side effects;
- use Principle of Least Astonishment when a name, type, return contract, or apparent query creates a concrete expectation that the behavior violates.

This distinction is for selecting a useful finding, not for emitting one finding under every related principle.

## Balancing Principles

- DRY removes duplicated knowledge; wait for evidence before abstracting merely similar code.
- OCP supports real, recurring variation; do not add extension mechanisms for imagined requirements.
- DIP protects meaningful boundaries; do not create an interface for every class.
- SRP and SoC improve cohesion; do not split a cohesive operation into fragments that are harder to understand together.
- FCoI is a preference when reuse or change drives the design; inheritance remains appropriate for a genuine substitutable hierarchy or framework contract that satisfies LSP.
- IOSP and Single Level of Abstraction can clarify orchestration and logic; do not extract one-line wrappers or forbid ordinary value-object and language operations mechanically.
- Information Hiding, Tell, Don't Ask, and LoD improve encapsulation; do not move behavior onto an object that lacks the information or responsibility to own it.
- KISS and YAGNI actively counter unnecessary patterns, abstractions, configurability, and indirection proposed in the name of another principle.
- When principles pull in different directions, explain the concrete trade-off and choose the design that makes the current behavior easiest to understand and change safely.

## Implementation Self-Review

After a non-trivial implementation or refactor, inspect the resulting diff with the same workflow used for a manual review. Challenge newly introduced code for meaningful duplication, avoidable complexity, speculative abstractions, inappropriate inheritance, mixed abstraction levels, mixed responsibilities or concerns, leaking implementation details, excessive collaborator knowledge, broad interfaces, undesirable dependency direction, broken substitutability, surprising behavior, and gaps between the intended design and the source structure.

Fix material issues before finalizing when they are within the requested scope. Report unresolved findings with their canonical principle names. A successful self-review may conclude that no relevant principle violation was found. In that case, state the conclusion without naming principles that were considered, passed, or found inapplicable.

## Manual Review Output

Report findings in severity order with file and line references when available. Integrate them with the review's existing severity and prioritization system. Each design finding should contain:

- the canonical principle name, including its abbreviation where one is defined;
- the affected code and concrete problem;
- the likely consequence;
- the smallest practical improvement;
- test impact when the change needs verification.

Lead with the principle, for example:

> **SRP — Single Responsibility Principle:** `OrderService` handles persistence, pricing, and email notification, so unrelated changes repeatedly touch the same class.

> **LoD — Law of Demeter:** `order.customer().address().country().code()` couples this service to the customer/address object graph.

Do not replace the principle name with a vague observation such as “this class does too much.” If several principles describe the same issue, name the one that best explains the risk and mention another only when it adds useful guidance. If there are no meaningful findings, say so without printing a principle-by-principle checklist.

## Refactoring Constraints

- Preserve externally visible behavior unless the user explicitly asked to change it.
- Refactor in small steps and make larger structural changes only with an adequate safety net; follow `php-testing-style` for characterization or focused tests.
- Prefer rename, extract method, extract class or collaborator, and move method before a larger redesign.
- Prefer named cohesive collaborators over broad utility classes.
- Use a pattern only when it simplifies a current problem and matches existing project language.
- Remove duplicated knowledge, not merely similar-looking code.
- Prefer executable vertical slices over horizontal infrastructure-only expansion unless the user requested foundation work.
- Treat metrics and static-analysis warnings as evidence to investigate, not automatic design conclusions.
- Keep cleanup local to the requested change.
