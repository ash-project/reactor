defmodule Reactor.Magic do
  @moduledoc """
  Look its magic.

    defmodule Foo do
     import Reactor.Magic

     def_reactor say_hello(name) do
       a = "Hello, "
       b = run_step(
         Reactor.Step.Template, 
         %{a: a, b: name}, 
         template: "<%= @a %><%= @b %>"
       )
       "I just said: #{b}"
     end
    end
  """
  defmacro run_step(_mod, _args) do
    raise "Used `run_step/2` in an unsupported context or with unsupported args"
  end

  defmacro def_reactor({func, _, args}, do: body) do
    args_as_map =
      Enum.map(args, fn {name, _, _} ->
        {name, {name, [], nil}}
      end)

    arg_names =
      Enum.map(args, fn {name, _, _} ->
        name
      end)

    arg_count = Enum.count(args)

    reactor = Module.concat([__CALLER__.module, Reactors, Macro.camelize("#{func}#{arg_count}")])

    {reactor_body, returns} =
      Reactor.Magic.to_reactor_dsl(
        body,
        Enum.map(arg_names, &{&1, :input}),
        %{step_name: {"a", 0}}
      )

    returns = to_name(returns)

    quote do
      def unquote(:"#{func}!")(unquote_splicing(args), opts \\ []) do
        Reactor.run!(
          unquote(reactor),
          %{
            unquote_splicing(args_as_map)
          },
          opts[:context] || %{},
          opts
        )
      end

      defmodule unquote(reactor) do
        use Reactor

        for name <- unquote(arg_names) do
          input name
        end

        unquote(reactor_body)

        return unquote(returns)
      end
    end
  end

  @doc false
  def to_reactor_dsl(ast, bindings, acc) do
    case ast do
      {:__block__, _, children} ->
        step_name = increment_step_letter(acc.step_name)

        children
        |> Enum.reduce({[], bindings, step_name}, fn
          {:=, _, [{var, _, _}, body]}, {blocks, bindings, step_name} ->
            block =
              make_step(body, bindings, step_name)

            new_step_name = increment_step_number(step_name)
            {[block | blocks], Keyword.put(bindings, var, {:result, step_name}), new_step_name}

          body, {blocks, bindings, step_name} ->
            block =
              make_step(body, bindings, step_name)

            new_step_name = increment_step_number(step_name)
            {[block | blocks], bindings, new_step_name}
        end)

      other ->
        {make_step(other, bindings, acc.step_name), bindings,
         increment_step_number(acc.step_name)}
    end
    |> then(fn {body, _bindings, name} ->
      {body, decrement_step_number(name)}
    end)
  end

  defp increment_step_letter({letter, number}) do
    {prefix, last_letter} = String.split_at(letter, -1)

    next_letter =
      if last_letter == "z" do
        prefix <> "za"
      else
        prefix <> <<hd(String.to_charlist(last_letter)) + 1::utf8>>
      end

    {next_letter, number}
  end

  defp increment_step_number({name, number}), do: {name, number + 1}
  defp decrement_step_number({name, number}), do: {name, number - 1}

  defp make_step(
         {:run_step, meta_a, [{:__aliases__, _, _} = step_type, map]},
         bindings,
         step_name
       ) do
    make_step({:run_step, meta_a, [step_type, map, []]}, bindings, step_name)
  end

  defp make_step(
         {:run_step, _, [{:__aliases__, _, _} = step_type, {:%{}, _, keys}, opts]},
         bindings,
         step_name
       )
       when is_list(keys) and is_list(opts) do
    bindings_as_arguments =
      Enum.map(keys, fn
        {key, {var, _, _}} ->
          case Keyword.fetch(bindings, var) do
            {:ok, :input} ->
              quote do
                Reactor.Dsl.Reactor.Step.Reactor.Arguments.Argument.argument(
                  unquote(key),
                  Reactor.Dsl.Argument.input(unquote(var))
                )
              end

            {:ok, {:result, step_name}} ->
              quote do
                Reactor.Dsl.Reactor.Step.Reactor.Arguments.Argument.argument(
                  unquote(key),
                  Reactor.Dsl.Argument.result(unquote(to_name(step_name)))
                )
              end

            :error ->
              raise "No such usable variable: #{var}"
          end

        other ->
          raise "Unsupported step input: #{Macro.to_string(other)}"
      end)

    name = to_name(step_name)

    quote do
      require Reactor.Dsl.Step
      require Reactor.Dsl.Reactor.Step
      require Reactor.Dsl.Reactor.Step.Options
      require Reactor.Dsl.Reactor.Step.Reactor.Arguments.Argument

      Reactor.Dsl.Reactor.Step.step unquote(name), {unquote(step_type), unquote(opts)} do
        (unquote_splicing(bindings_as_arguments))
      end
    end
  end

  defp make_step(ast, bindings, step_name) do
    ast = {:ok, ast}

    {ast, {_, only_used}} =
      Macro.prewalk(ast, {bindings, MapSet.new()}, fn
        {var, _, ctx} = node, {bindings, used} = acc
        when is_atom(ctx) ->
          if Keyword.has_key?(bindings, var) do
            {quote do
               Map.fetch!(__reactor_input__, unquote(var))
             end, {bindings, MapSet.put(used, var)}}
          else
            {node, acc}
          end

        {:=, _, [{var, _, _}, _]} = node, {bindings, used} ->
          {node, {Keyword.delete(bindings, var), used}}

        # TODO: detect all assignments and remove from our bindings
        node, acc ->
          {node, acc}
      end)

    bindings = Keyword.take(bindings, MapSet.to_list(only_used))

    bindings_as_arguments =
      Enum.map(bindings, fn
        {name, :input} ->
          quote do
            Reactor.Dsl.Reactor.Step.Reactor.Arguments.Argument.argument(
              unquote(name),
              Reactor.Dsl.Argument.input(unquote(name))
            )
          end

        {name, {:result, step_name}} ->
          quote do
            Reactor.Dsl.Reactor.Step.Reactor.Arguments.Argument.argument(
              unquote(name),
              Reactor.Dsl.Argument.result(unquote(to_name(step_name)))
            )
          end
      end)

    name = to_name(step_name)

    quote do
      require Reactor.Dsl.Step
      require Reactor.Dsl.Reactor.Step
      require Reactor.Dsl.Reactor.Step.Options
      require Reactor.Dsl.Reactor.Step.Reactor.Arguments.Argument

      Reactor.Dsl.Reactor.Step.step unquote(name) do
        unquote_splicing(bindings_as_arguments)

        Reactor.Dsl.Reactor.Step.Options.run(fn __reactor_input__, _ ->
          unquote(ast)
        end)
      end
    end
  end

  defp to_name({letter, number}) do
    :"#{letter}_#{number}"
  end
end
