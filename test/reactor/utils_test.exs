# SPDX-FileCopyrightText: 2023 James Harton, Zach Daniel, Alembic Pty and contributors
#
# SPDX-License-Identifier: MIT

defmodule Reactor.UtilsTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Reactor.Utils

  describe "deep_merge/2" do
    test "it can deeply merge two maps" do
      lhs = %{a: %{b: %{c: %{d: :e}}}}
      rhs = %{a: %{b: %{c: %{e: :f}}, g: :h}}

      assert deep_merge(lhs, rhs) == %{a: %{b: %{c: %{d: :e, e: :f}}, g: :h}}
    end
  end

  describe "maybe_append/2" do
    test "it appends non-nil values to the collection" do
      assert [1, 2, 3] = maybe_append([1, 2], 3)
    end

    test "it does not append nil values to the collection" do
      assert [1, 2] = maybe_append([1, 2], nil)
    end
  end

  describe "maybe_append_result/2" do
    test "when the function returns a non-nil value, it is appended to the collection" do
      assert [1, 2, 3] = maybe_append_result([1, 2], fn -> 3 end)
    end

    test "when the function returns a nil value, it is not appended to the collection" do
      assert [1, 2] = maybe_append_result([1, 2], fn -> nil end)
    end
  end

  describe "sentence/4" do
    test "it converts a list of values into a sentence" do
      assert "a, b or c" = sentence(~w[a b c]a, &to_string/1, ", ", " or ")
    end
  end

  describe "map_while_ok/3" do
    test "when all the map functions return an ok tuple, it maps the collection" do
      assert {:ok, [2, 4, 6]} = map_while_ok([1, 2, 3], &{:ok, &1 * 2}, true)
    end

    test "when one of the map functions returns an error tuple, it returns the error" do
      assert {:error, :fail} =
               map_while_ok(
                 [1, 2, 3],
                 fn
                   i when rem(i, 2) == 0 -> {:error, :fail}
                   i -> {:ok, i * 2}
                 end,
                 true
               )
    end

    test "it doesn't preserve order by default" do
      assert {:ok, [6, 4, 2]} = map_while_ok([1, 2, 3], &{:ok, &1 * 2})
    end
  end

  describe "reduce_while_ok/3" do
    test "when all the reduce functions return an ok tuple, it reduces into an ok tuple" do
      assert {:ok, 12} = reduce_while_ok([1, 2, 3], 0, &{:ok, &2 + &1 * 2})
    end

    test "when one of the reduce functions returns an error tuple, it returns the error" do
      assert {:error, :fail} =
               reduce_while_ok([1, 2, 3], 0, fn
                 i, _acc when rem(i, 2) == 0 -> {:error, :fail}
                 i, acc -> {:ok, acc + i * 2}
               end)
    end
  end

  describe "argument_error/3" do
    test "it consistently formats the argument error message" do
      message = """
      `fruit` is not fruit

      ## Value of `fruit`

      ```
      :pepperoni
      ```
      """

      assert %ArgumentError{message: ^message} =
               argument_error(:fruit, "is not fruit", :pepperoni)
    end
  end
end
