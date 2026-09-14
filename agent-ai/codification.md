# Codification Rules

## Purpose

These rules define the coding standards for the `agent-ai` workspace and its related projects. The code must prioritize clarity, testability, maintainability, and explicit boundaries between responsibilities.

## Core Principles

1. **Single Responsibility Principle (SRP)**: each class, method, and module must have one clear responsibility.
2. **Open/Closed Principle (OCP)**: extend behavior through abstractions and new implementations instead of modifying stable logic unnecessarily.
3. **Liskov Substitution Principle (LSP)**: implementations must honor the contracts of their abstractions.
4. **Interface Segregation Principle (ISP)**: prefer small, focused interfaces over broad interfaces.
5. **Dependency Inversion Principle (DIP)**: high-level use cases must depend on abstractions, not infrastructure details.
6. **DRY (Don't Repeat Yourself)**: centralize duplicated rules, transformations, and validation logic.
7. **KISS (Keep It Simple)**: prefer the simplest design that satisfies the requirement.
8. **YAGNI (You Aren't Gonna Need It)**: do not introduce abstractions or features without a current use case.
9. **Fail Fast**: validate inputs and invariants before mutating the filesystem or external state.
10. **Separation of Concerns**: keep domain rules, application orchestration, infrastructure, and presentation independent.

## Naming

- Use descriptive names that express intent.
- Use English for code identifiers, types, methods, properties, folders, and files.
- Use PascalCase for classes, records, interfaces, enums, public methods, and public properties.
- Use camelCase for local variables and private fields when consistent with the language conventions.
- Prefix interfaces with `I`, for example `IPlanExecutor`.
- Use verbs for methods: `BuildPlan`, `ValidateConfiguration`, `RenderTemplate`, `ExecutePlan`.
- Use nouns for models and value objects: `GenerationPlan`, `MicroserviceConfiguration`, `ComponentDefinition`.
- Avoid abbreviations, unexplained acronyms, and one-letter names.
- Names must reveal intent instead of implementation details.

## Architecture

Use explicit boundaries between layers:

```text
Presentation
    -> Application
        -> Domain
    -> Infrastructure
```

### Presentation

- Parse CLI arguments and format user-facing output.
- Do not contain business rules or filesystem algorithms.
- Keep `Program.cs` limited to composition, dependency registration, and process exit codes.

### Application

- Coordinate use cases through `Application Service` or `Command Handler` classes.
- Define interfaces for infrastructure dependencies.
- Control transaction boundaries and execution order.

### Domain

- Contain business rules, invariants, entities, value objects, and domain services.
- Do not depend on JSON serialization, CLI frameworks, or filesystem APIs.
- Prefer immutable models where practical.

### Infrastructure

- Implement repositories, JSON readers, template loaders, filesystem writers, and logging adapters.
- Keep external concerns behind interfaces consumed by the Application layer.

## Design Patterns

Use patterns only when they solve a concrete problem. Preferred patterns for the generator are:

- `Application Service` for use-case orchestration.
- `Builder` for constructing `GenerationPlan` incrementally.
- `Strategy` for backend, frontend, and cloud generation variants.
- `Factory Method` or `Abstract Factory` for component creation and resolution.
- `Repository` for JSON, template, and filesystem access.
- `Chain of Responsibility` for independent validation rules.
- `Interpreter` or a dedicated `Template Renderer` for placeholder replacement.
- `Facade` for exposing a simple generation API.
- `Dependency Injection` for explicit dependency management.

Do not add a pattern only to make the architecture look more sophisticated. A direct implementation is preferred when the behavior is simple.

## .NET Conventions

- Enable nullable reference types.
- Use `record` types for immutable configuration and plan data when appropriate.
- Use `async` APIs for I/O when the surrounding API is asynchronous.
- Use `System.Text.Json` consistently unless another serializer is explicitly required.
- Keep public APIs small and explicit.
- Prefer constructor injection over service locator access.
- Avoid static mutable state.
- Dispose streams, readers, and other disposable resources deterministically.
- Use specific exception types and messages that identify the invalid input.
- Do not swallow exceptions silently.

## Generator Rules

- Treat `epc.json` as input configuration, not as a generated artifact.
- Resolve component definitions from the configured component directories.
- Keep `templates` and `defaults` inside the corresponding component directory.
- Build one deterministic `generation-plan.json` for the selected environment.
- Render templates before executing filesystem changes.
- Fail before writing output when configuration, paths, duplicates, relations, or placeholders are invalid.
- Reject absolute paths and traversal segments such as `..`.
- Detect duplicate output paths across components and microservices.
- Keep source paths and output paths conceptually separate.
- Do not overwrite conflicting generated files implicitly.
- Preserve the distinction between rendered files and copied default files.

## Validation and Errors

- Validate required configuration before resolving components.
- Validate environment existence and required variables.
- Validate duplicate ports and duplicate output paths.
- Validate referenced entities and bidirectional relations.
- Validate template placeholders and fail on unresolved values.
- Include the relevant file, property, or path in error messages.
- Stop the generation process on the first invalid state when partial output would be unsafe.

## Message Handling

- Do not hard-code user-facing messages inside business logic.
- Centralize fixed messages in a `MessageCatalog` or `GeneratorMessages` class.
- Use methods for messages with dynamic values.
- Assign stable `ErrorCodes` such as `GEN001` to actionable generator errors.
- Use a domain-specific exception such as `GeneratorException` for errors that need a stable code.
- Preserve specific framework exceptions when their type is useful, but obtain their message from the catalog.
- CLI output should follow a compact format: `<error-code>: <message>`.
- Do not introduce localization infrastructure until the project requires multiple languages.

## Hardcoded Values

- Do not embed configurable, repeated, or domain-significant values directly in business logic.
- Use `const` for immutable technical values such as file names, folder names, placeholder keys, and error codes.
- Use `Options Pattern` or JSON configuration for values that may vary by environment, installation, or deployment.
- Use `enum` for closed sets of supported values.
- Keep user-facing messages in `GeneratorMessages`, not in services or validators.
- Keep component-specific values in component configuration, not in C# constants.
- Do not extract every literal automatically; extract values that have semantic meaning, are reused, or are likely to change.
- Prefer names such as `GenerationPlanFileName` over literals such as `"generation-plan.json"`.

## Testing

- Add unit tests for validators, path normalization, placeholder rendering, relation rules, and plan construction.
- Add integration tests for the complete CLI flow using temporary directories.
- Test both successful generation and expected failures.
- Keep tests deterministic and independent of the developer machine.
- Test filesystem behavior without modifying production fixtures.
- Run the narrowest relevant test first, then the complete test suite.

## Change Discipline

- Make the smallest change that solves the requirement.
- Preserve existing public contracts unless a breaking change is required.
- Avoid unrelated refactors in the same change.
- Update documentation when configuration or CLI behavior changes.
- Review the diff before finishing.
- Never commit or reset repository state unless explicitly requested.
