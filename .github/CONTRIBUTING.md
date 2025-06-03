# Contributing to Reactor

## Welcome!

We are delighted to have anyone contribute to Reactor, regardless of their skill level or background. We welcome contributions both large and small, from typos and documentation improvements, to bug fixes and features. There is a place for everyone's contribution here. Check the issue tracker or join the ElixirForum/discord server to see how you can help! Make sure to read the rules below as well.

## Contributing to Documentation

Documentation contributions are one of the most valuable kinds of contributions you can make! Good documentation helps everyone in the community understand and use Ash more effectively.

The best way to contribute to documentation is often through GitHub's web interface, which allows you to make changes without having to clone the code locally:

**For Guides:**
- While viewing any guide on the documentation website, look for the `</>` button in the top right of the page
- Clicking this button will take you directly to GitHub's editing interface for that file

**For Module Documentation:**
- When viewing module documentation, the `</>` button will also be in the top right of the page

**For Function Documentation:**
- When viewing individual functions, you'll find the `</>` button next to the function header

Once you click the `</>` button, GitHub will:
1. Fork the repository for you (if you haven't already)
2. Open the file in GitHub's web editor
3. Allow you to make your changes directly in the browser
4. Help you create a pull request with your improvements

This workflow makes it incredibly easy to fix typos, clarify explanations, add examples, or improve any part of the documentation you encounter while using Ash.

## Rules

* We have a zero tolerance policy for failure to abide by our code of conduct. It is very standard, but please make sure you have read it.
* Issues may be opened to propose new ideas, to ask questions, or to file bugs.
* Before working on a feature, please talk to the core team/the rest of the community via a proposal. We are building something that needs to be cohesive and well thought out across all use cases. Our top priority is supporting real life use cases like yours, but we have to make sure that we do that in a sustainable way. The best compromise there is to make sure that discussions are centered around the *use case* for a feature, rather than the proposed feature itself.
* Before starting work, please comment on the issue and/or ask in the discord if anyone is handling an issue. Be aware that if you've commented on an issue that you'd like to tackle it, but no one can reach you and/or demand/need arises sooner, it may still need to be done before you have a chance to finish. However, we will make all efforts to allow you to finish anything you claim.

## Local Development & Testing

### Setting Up Your Development Environment

1. **Fork and clone the repository:**
   ```bash
   git clone https://github.com/your-username/reactor.git
   cd reactor
   ```

2. **Install dependencies:**
   ```bash
   mix deps.get
   ```

3. **Compile the project:**
   ```bash
   mix compile
   ```

### Running Tests and Checks

Before submitting any pull request, please run the full test suite and quality checks locally:

```bash
mix check
```

This command runs a comprehensive suite of checks including:
- Compilation
- Tests
- Code formatting (via `spark.formatter`)
- Credo (static code analysis)
- Dialyzer (type checking)
- Documentation generation and validation
- Sobelow (security analysis)
- And other quality checks

You can also run individual checks:
- `mix test` - Run the test suite
- `mix format` - Format code
- `mix credo` - Run static analysis
- `mix dialyzer` - Run type checking
- `mix docs` - Generate documentation

### Testing Ash with Your Application

If you want to test your Ash changes with your own application, you can use Ash as a local dependency. In your application's `mix.exs`, replace the hex dependency with a path dependency:

```elixir
defp deps do
  [
    # Replace this:
    # {:reactor, "~> 3.0"}

    # With this (adjust path as needed):
    {:reactor, path: "../reactor"},

    # Your other dependencies...
  ]
end
```

Then run:
```bash
mix deps.get
mix compile
```

This allows you to:
- Test your changes against real-world usage
- Verify that your changes don't break existing functionality
- Develop features iteratively with immediate feedback

Testing in your own application is not sufficient, you must also include automated tests.

### Development Workflow

1. **Create a feature branch:**
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes** and write tests

3. **Run the full check suite:**
   ```bash
   mix check
   ```

4. **Commit your changes:**
   ```bash
   git add .
   git commit -m "Add feature description"
   ```

5. **Push and create a pull request**

### Common Development Tasks

- **Generate documentation:** `mix docs`
- **Run tests in watch mode:** `mix test.watch`
- **Check formatting:** `mix format --check-formatted`
- **Run specific test file:** `mix test test/path/to/test_file.exs`
- **Run tests with coverage:** `mix test --cover`
