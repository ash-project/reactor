defmodule Mix.Tasks.Reactor.MermaidTest do
  @moduledoc false
  use ExUnit.Case

  import ExUnit.CaptureIO

  alias Mix.Tasks.Reactor.Mermaid

  describe "run/1" do
    test "handles module names with leading whitespace" do
      # Test that module names with leading whitespace are properly trimmed
      output =
        capture_io(fn ->
          Mermaid.run([" Example.BasicReactor", "--format", "copy"])
        end)

      assert output =~ "✅ Mermaid diagram for copy-paste:"
      assert output =~ "flowchart"
    end

    test "handles module names with trailing whitespace" do
      # Test that module names with trailing whitespace are properly trimmed
      output =
        capture_io(fn ->
          Mermaid.run(["Example.BasicReactor ", "--format", "copy"])
        end)

      assert output =~ "✅ Mermaid diagram for copy-paste:"
      assert output =~ "flowchart"
    end

    test "handles module names with both leading and trailing whitespace" do
      # Test that module names with both leading and trailing whitespace are properly trimmed
      output =
        capture_io(fn ->
          Mermaid.run([" Example.BasicReactor ", "--format", "copy"])
        end)

      assert output =~ "✅ Mermaid diagram for copy-paste:"
      assert output =~ "flowchart"
    end

    test "handles module names with tabs and other whitespace characters" do
      # Test that module names with various whitespace characters are properly trimmed
      output =
        capture_io(fn ->
          Mermaid.run(["\t Example.BasicReactor\n ", "--format", "copy"])
        end)

      assert output =~ "✅ Mermaid diagram for copy-paste:"
      assert output =~ "flowchart"
    end

    test "works with clean module names (no regression)" do
      # Test that clean module names still work as expected
      output =
        capture_io(fn ->
          Mermaid.run(["Example.BasicReactor", "--format", "copy"])
        end)

      assert output =~ "✅ Mermaid diagram for copy-paste:"
      assert output =~ "flowchart"
    end
  end
end
