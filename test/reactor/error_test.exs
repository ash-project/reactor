# SPDX-FileCopyrightText: 2023 James Harton, Zach Daniel, Alembic Pty and contributors
#
# SPDX-License-Identifier: MIT

defmodule Reactor.ErrorTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias Reactor.{Error, Error.Invalid.UndoStepError, Error.Unknown, Error.Unknown.UnknownError}

  describe "fetch_error/2" do
    test "when the error is of the provided type, it returns it" do
      error = UnknownError.exception(error: "🤔")

      assert {:ok, ^error} = Error.fetch_error(error, UnknownError)
    end

    test "when the error is not of the provided type, it returns an error atom" do
      error = Unknown.exception(errors: [])

      assert :error = Error.fetch_error(error, UnknownError)
    end

    test "when the error directly contains the provided type, it returns it" do
      nested = UndoStepError.exception()
      error = UnknownError.exception(error: nested)

      assert {:ok, ^nested} = Error.fetch_error(error, UndoStepError)
    end

    test "when the error collects the provided type, it returns the first match" do
      nested0 = UnknownError.exception(error: "0")
      nested1 = UnknownError.exception(error: "1")
      error = Unknown.exception(errors: [nested0, nested1])

      assert {:ok, ^nested0} = Error.fetch_error(error, UnknownError)
    end

    test "it searches recursively" do
      root = UndoStepError.exception()

      error =
        Unknown.exception(
          errors: [
            UnknownError.exception(
              error:
                Unknown.exception(
                  errors: [
                    UnknownError.exception(error: root)
                  ]
                )
            )
          ]
        )

      assert {:ok, ^root} = Error.fetch_error(error, UndoStepError)
    end
  end

  describe "find_errors/2" do
    test "when the error is the provided type it returns it" do
      error = UnknownError.exception(error: "🤔")
      assert [^error] = Error.find_errors(error, UnknownError)
    end

    test "when the error directly contains the provided type it returns it" do
      nested = UndoStepError.exception()
      error = UnknownError.exception(error: nested)

      assert [^nested] = Error.find_errors(error, UndoStepError)
    end

    test "when the error collects the provided type, it returns all instances of it" do
      nested0 = UnknownError.exception(error: "0")
      nested1 = UnknownError.exception(error: "1")
      error = Unknown.exception(errors: [nested0, nested1])

      assert [^nested0, ^nested1] = Error.find_errors(error, UnknownError)
    end

    test "it searches recursively" do
      nested0 = UndoStepError.exception(step: :zero)
      nested1 = UndoStepError.exception(step: :one)
      nested2 = UndoStepError.exception(step: :two)

      error =
        Unknown.exception(
          errors: [
            UnknownError.exception(
              error:
                Unknown.exception(
                  errors: [
                    Unknown.exception(
                      errors: [
                        UnknownError.exception(error: nested2)
                      ]
                    ),
                    nested1
                  ]
                )
            ),
            nested0
          ]
        )

      assert [^nested2, ^nested1, ^nested0] = Error.find_errors(error, UndoStepError)
    end
  end
end
