# SPDX-FileCopyrightText: 2023 James Harton, Zach Daniel, Alembic Pty and contributors
#
# SPDX-License-Identifier: MIT

defmodule Example.HelloWorldReactor do
  @moduledoc false
  use Reactor, otp_app: :reactor

  input :whom

  step :greet, Example.Step.Greeter do
    argument :whom, input(:whom)
  end

  return :greet
end
