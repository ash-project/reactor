defmodule Reactor.Dsl.TemplateTest do
  @moduledoc false
  use ExUnit.Case, async: true

  defmodule TemplateReactor do
    @moduledoc false
    use Reactor

    input :name
    input :location

    template :greet do
      argument :name, input(:name)
      argument :location, input(:location)

      template("""
      Hi <%= @name %>, welcome to <%= @location %>! 🎉
      """)
    end

    return :greet
  end

  test "it renders the template" do
    assert {:ok, result} =
             Reactor.run(TemplateReactor, %{name: "Marty McFly", location: "Hill Valley Mall"})

    assert result == "Hi Marty McFly, welcome to Hill Valley Mall! 🎉\n"
  end
end
