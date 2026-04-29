---
name: tdd
description: "Test-Driven Development workflow - red/green/refactor cycles with explicit phase prompting"
trigger: /tdd
---

# /tdd

Test-Driven Development using strict red-green-refactor cycles. Tests drive design, not validate existing code.

## Workflow

### Red Phase
Write a FAILING test for the feature. Do NOT write implementation yet.
- Use Arrange-Act-Assert pattern
- Descriptive test names that document behavior
- Run test to confirm it fails

### Green Phase
Implement minimum code to make tests pass. Only write enough to satisfy current tests.
- No extra features
- No premature abstractions
- Run tests to confirm green

### Refactor Phase
Improve code quality. Tests must stay green.
- Extract duplication
- Improve naming
- Simplify logic
- Run tests after each change

## Rules

1. Never combine red and green phases in one step
2. Never write implementation before tests
3. Never skip the refactor phase
4. Each cycle handles one behavior/requirement
5. Run tests after every phase

## Usage

```
/tdd                          # start TDD cycle, ask what to build
/tdd <feature description>    # begin red phase for described feature
```

## Integration

- Use Plan Mode to explore test strategy before starting
- Track phases with tasks
- Auto-run tests via hooks when test files change
