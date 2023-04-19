import Config

if Mix.env() == :dev do
  config :git_ops,
    mix_project: Reactor.MixProject,
    changelog_file: "CHANGELOG.md",
    repository_url: "https://github.com/ash-project/reactor",
    # Instructs the tool to manage your mix version in your `mix.exs` file
    # See below for more information
    manage_mix_version?: true,
    # Instructs the tool to manage the version in your README.md
    # Pass in `true` to use `"README.md"` or a string to customize
    manage_readme_version: true,
    version_tag_prefix: "v"
end
