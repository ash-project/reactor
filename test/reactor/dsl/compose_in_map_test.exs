# SPDX-FileCopyrightText: 2023 James Harton, Zach Daniel, Alembic Pty and contributors
# SPDX-FileCopyrightText: 2023 reactor contributors <https://github.com/ash-project/reactor/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Reactor.Dsl.ComposeInMapTest do
  @moduledoc false
  use ExUnit.Case, async: true

  describe "compose step inside map can use map's arguments" do
    defmodule BuildRecord do
      use Reactor

      input(:item)
      input(:name_id_map)

      step :build_record do
        argument :item, input(:item)
        argument :name_id_map, input(:name_id_map)

        run fn %{name_id_map: name_id_map, item: item}, _context ->
          id = Map.get(name_id_map, item["name"], nil)
          {:ok, Map.put(item, "id", id)}
        end
      end
    end

    defmodule ComposeInMapReactor do
      use Reactor

      input(:items)

      step :get_name_to_id_map do
        run fn _args, _context ->
          name_id_map = Map.new(0..10, fn i -> {"name_#{i}", i} end)
          {:ok, name_id_map}
        end
      end

      map :build_records do
        source input(:items)
        allow_async?(true)
        argument :name_id_map, result(:get_name_to_id_map)

        compose :build_record, BuildRecord do
          argument :item, element(:build_records)
          # With our fix, this should no longer be needed:
          # argument :name_id_map, value(nil)
        end
      end
    end

    test "compose step should inherit map's arguments" do
      items = [
        %{"name" => "name_0"},
        %{"name" => "name_2"}
      ]

      # This should now work with our fix
      result = Reactor.run!(ComposeInMapReactor, %{items: items}, %{}, async?: false)

      assert [
               %{"id" => 0, "name" => "name_0"},
               %{"id" => 2, "name" => "name_2"}
             ] = result
    end
  end
end
