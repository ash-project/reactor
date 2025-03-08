defmodule Example.HelloWorldReactor do
  @moduledoc false
  use Reactor, otp_app: :reactor

  input :whom

  step :greet, Example.Step.Greeter do
    argument :whom, input(:whom)
  end

  return :greet
end
