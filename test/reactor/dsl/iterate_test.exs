defmodule Reactor.Dsl.IterateTest do
  use ExUnit.Case, async: true

  test "wat" do
    defmodule WordReverseReactor do
      @moduledoc false
      use Reactor

      input :words

      iterate :reverse_words do
        argument :words, input(:words)

        source do
          initialiser &{:ok, &1.words}

          generator fn words ->
            case String.split(words, ~r/\s+/, parts: 2, trim: true) do
              [] -> {:halt, ""}
              [word] -> {:cont, [%{word: word}], ""}
              [word, remaining] -> {:cont, %{word: word}, remaining}
            end
          end
        end

        map do
          step :reverse_word do
            argument :word, element(:word)

            run &{:ok, String.reverse(&1.word)}
          end
        end

        reduce do
          accumulator fn -> {:ok, ""} end

          reducer fn word, acc ->
            {:cont, acc <> " " <> word}
          end
        end
      end
    end
  end
end
