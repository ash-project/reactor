# SPDX-FileCopyrightText: 2023 James Harton, Zach Daniel, Alembic Pty and contributors
#
# SPDX-License-Identifier: MIT

defmodule Example.BasicReactor do
  @moduledoc false
  use Reactor

  defmodule DrinkingAgeVerifier do
    @moduledoc false
    use Reactor.Step

    def run(arguments, _context, _options) when arguments.age >= 18 and arguments.country == :nz,
      do: {:ok, true}

    def run(arguments, _context, _options) when arguments.age >= 21 and arguments.country == :usa,
      do: {:ok, true}

    def run(_arguments, _context, _options), do: {:ok, false}
  end

  input :age
  input :country

  step :verify, DrinkingAgeVerifier do
    argument :age, input(:age)
    argument :country, input(:country)
  end
end
