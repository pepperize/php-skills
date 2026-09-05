---
name: php-testing-style
description: Use when adding or changing PHPUnit tests, fixing failing tests, doing TDD, choosing unit versus integration coverage, or selecting Composer/PHPUnit verification scope.
---

# PHP Testing Style

## Default Heuristics

- Prefer FIRST: Fast, Isolated, Repeatable, Self-Verifying, and Timely.
- Prefer OTAO: one test covers one behavior and ideally has one reason to fail. Multiple assertions are fine when they verify that same behavior.
- Name unit tests `given{SomeCondition}_should{ExpectedResult}` and mark them with PHPUnit's `#[Test]` attribute when their names do not use PHPUnit's `test...` discovery prefix.
- Name the observed value `$actual`.
- Use PHPUnit assertions from `PHPUnit\Framework\TestCase`; do not introduce Pest or another assertion style unless the project requires it or the user asks for it.
- Keep assertions simple and readable.
- Do not add tests for unchanged existing behavior solely because an acceptance criterion mentions it. Test the regression risk introduced by the change at the boundary where the new composition occurs, and rely on existing collaborator contracts unless those contracts or their integration changed.

## Unit Tests

- Default to London-style unit tests for application services, use cases, orchestration classes, ports, and clients.
- Prefer mocking all collaborators, including simple configuration holders, when that keeps the system under test declarative and explicitly constructed.
- Avoid `setUp()` methods that only wire dependencies into the system under test.
- Use real collaborators only when they are intentionally part of the behavior under test and do not turn the test into a boundary integration test.
- Prefer explicit assertions and interaction expectations over indirect failure-by-missing-stub setups.
- In interaction-based tests, verify the end of the signal path at the relevant boundary; verify intermediate interactions only when they are the behavior under test.
- Prefer direct value verification with PHPUnit mock expectations and `with($expectedRequest)` when the argument has meaningful value equality and the expected value is easy to construct. Use callbacks only when direct equality is unavailable, partial matching is clearer, or the captured argument supports multiple observations.
- Do not mix state/assertion-style and interaction-style verification for the same behavior in one unit test.

## Test Layout

- When test data represents the same concept as a production value, use the same domain-oriented variable name unless the test needs to distinguish expected, actual, or multiple variants.
- Prefer code locality over front-loaded variable blocks. Create inputs, expected values, and intermediates near the mock expectation, act step, or assertion that uses them.
- Do not split setup into a front-loaded data block followed by a separate stubbing block. Keep setup in execution order.
- Use empty lines only between major blocks such as Arrange/Act/Assert or Given/When/Then.
- For repeated interactions such as loop iterations, order setup in the same sequence as the code under test.

## Exception Assertions

- When using PHPUnit's `expectException(...)` for an unchecked exception, prepare unrelated constructors, factories, collection creation, accessors, and argument-building calls before setting the expectation.
- After setting the exception expectation, invoke exactly the operation under test that may throw.
- Keep extracted inputs close to the invocation so the exception source remains obvious.
- Keep construction after `expectException(...)` only when that construction is itself the operation under test.
- Do not hide multiple invocations in a helper merely to satisfy static analysis.

```php
$locales = [$german];

$this->expectException(RuntimeException::class);
$sut->load($locales);
```

## Parameterized Tests

- Prefer a PHPUnit data provider when multiple tests exercise the same behavior, vary only input data, and assert the same outcome or violation path.
- Group invalid values for the same property into one parameterized test, such as `givenInvalidRegionCode_shouldFailValidation`.
- Use a simple static data provider returning named array cases before introducing more complex generators or helper objects.
- Do not fold cases into a parameterized test when setup becomes less readable, such as null array values requiring substantially different construction.
- Name the test after the shared behavior, not every individual case.

## Integration Tests

- Place integration tests at technical boundaries where framework or infrastructure behavior is the risk: controllers, authentication, authorization, binding, serialization, repositories, and external clients with stable realistic infrastructure such as containers or local service emulators.
- Use unit tests instead for external systems that cannot be exercised stably and realistically.
- Keep lightweight unit tests under `tests/Unit` and integration tests under `tests/Integration` unless the project establishes different directories.
- Name PHPUnit test classes and files with a `Test` suffix. Use the integration-test directory to communicate scope rather than adding redundant `IntegrationTest` suffixes.
- Tests using a framework kernel or container, an HTTP test client, containers, real repositories, or other framework/infrastructure boundaries belong under the project's integration-test directory.

## Persistent Test Data

- Arrange persistent state through the narrowest existing API that owns the responsibility for that state.
- Prefer existing services or use cases when setup must satisfy business rules, side effects, or cross-aggregate invariants.
- Prefer repositories when the test only needs already-valid persisted entities and repository behavior is not the subject under test.
- Use test data builders, fixture factories, or project-local test helpers for object construction; keep persistence, business behavior, and object construction in separate helpers.
- Do not embed SQL statements in PHP test code, including direct connection calls, native queries, or multiline SQL strings.
- When SQL is genuinely necessary for database-boundary setup, put it in dedicated `.sql` files under test resources or fixtures and load those files through the project's established test mechanism.
- Keep schema changes in migrations, not PHP tests or inline test setup.

## Verification

Run the narrowest command that credibly verifies the change before broadening.

For database, configuration, migration, dependency, template, or resource changes that can affect application boot, include project-documented startup verification in the final verification scope, not just unit tests.

- Mapper, factory, and small service changes: focused PHPUnit tests first.
- Use case and adapter orchestration changes: affected unit test classes.
- Controller, authorization, and event-listener changes: relevant integration tests.
- Persistence, object storage, file parsing, and infrastructure boundaries: boundary integration tests plus focused unit tests around helper collaborators when present.

## Verification Scope Review

Before broadening test scope:

- Run the narrowest affected PHPUnit test classes first.
- Do not run broad suites when known environment-dependent tests are unrelated to the change.
- If a focused test failure exposes a wrong assumption, fix the production assumption first instead of adding test-only branches.

## Required Pre-Final Test Review

- Inspect every added or changed unchecked-exception assertion. Keep the code after `expectException(...)` limited to the direct operation under test, with potentially throwing setup calls evaluated beforehand.
