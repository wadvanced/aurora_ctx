# Contributing to Aurora.Ctx

Thank you for your interest in contributing to Aurora.Ctx! This guide will help you set up your development environment and run the test suite.

## Development Setup

1. Ensure you have the following prerequisites installed:
   - Elixir ~> 1.17
   - PostgreSQL

2. Clone the repository:
   ```bash
   git clone https://github.com/wadvanced/aurora_ctx.git
   cd aurora_ctx
   ```

3. Install dependencies:
   ```bash
   mix deps.get
   ```

## Configuration

1. Optional: Configure your test database in `config/test.exs`. By default, configuration is obtained from `test/config/test.exs`:
   ```elixir
   config :aurora_ctx, Aurora.Ctx.Repo,
     database: "aurora_ctx_repo",
     username: "postgres",
     password: "postgres",
     hostname: "localhost",
     pool: Ecto.Adapters.SQL.Sandbox
   ```

2. Optional: Configure default pagination settings:
   ```elixir
   config :aurora_ctx, :paginate,
     page: 1,
     per_page: 40
   ```

## Running Tests

1. Create and migrate the test database:
   ```bash
   MIX_ENV=test mix ecto.create
   MIX_ENV=test mix ecto.migrate
   ```

2. Run the test suite:
   ```bash
   mix test
   ```

3. Run specific test files:
   ```bash
   mix test test/cases/core_test.exs
   ```

## Code Quality Tools

The project uses several code quality tools that should be run before submitting changes, they are Credo, Dyalizer and Doctor. 
The `mix consistency` task, besides running the above tools, also formats the source code. Of course, you can run them individually:

1. Run Credo for code style checking:
   ```bash
   mix credo
   ```

2. Run Dialyzer for static analysis:
   ```bash
   mix dialyzer
   ```

3. Run Doctor for documentation checking:
   ```bash
   mix doctor
   ```

## Documentation
Documentation is mostly reviewed or created by using AI tools.
There are several manual prompts useful for AI chat. Keep in mind that each AI provider propose a different documentation format, these prompts do their best to keep the documentation consistent. No matter which AI tool you use, please make sure that the documentation complies with the 
[Github module documentation prompt](.github/prompts/module_documentation.prompt.md). It is advisable to:

1. Generate documentation locally to check its quality:
   ```bash
   mix docs
   ```

2. Documentation will be available in the `doc/` directory.

## Making Changes

1. Create a new branch for your changes:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. Make your changes and ensure:
   - All tests pass
   - Documentation is updated and follow the guidelines
   - Code follows the existing style
   - New features include tests

3. Submit a Pull Request with:
   - A clear description of the changes
   - Any relevant issue numbers
   - Updates to documentation if needed

## Project Structure

- `/lib` - Source code
  - `/aurora` - Core functionality
    - `/ctx` - Context and query building modules
- `/test` - Test files
  - `/cases` - Test cases for different features
  - `/support` - Test helpers and shared code
  - `/config` - Test configuration
- `/guides` - Documentation guides
- `/doc` - Generated documentation

## Need Help?

If you need help with your contribution, feel free to:
- Open an issue for discussion
- Ask questions in pull requests
- Refer to existing tests for examples

## Useful links
[Aurora framework](https://github.com/wadvanced/aurora)
[Aurora.ctx documentation](https://hexdocs.pm/aurora_ctx)
[Ecto documentation](https://hexdocs.pm/ecto)
[ExDoc documentation](https://hexdocs.pm/ex_doc)
