defmodule Elisp.Env do
  alias Elisp.Symbol

  def start_link(parent \\ nil, frame \\ %{}) do
    Agent.start_link(fn -> %{frame: frame, parent: parent} end)
  end

  def get_var(nil, _, %Symbol{} = s), do: s
  def get_var(nil, _, s), do: %Symbol{value: s}

  def get_var(pid, key, s) do
    Agent.get(pid, fn %{frame: frame, parent: parent} ->
      case Map.get(frame, key) do
        nil -> get_var(parent, key, s)
        value -> value
      end
    end)
  end

  def def_var(pid, key, value) do
    Agent.update(pid, fn %{frame: frame} = state ->
      %{state | frame: Map.put(frame, key, value)}
    end)
  end

  def set_var(pid, key, value) do
    Agent.update(pid, fn %{frame: frame, parent: parent} = state ->
      case Map.get(frame, key) do
        nil -> set_var(parent, key, value)
        true -> %{state | frame: %{frame | key => value}}
      end
    end)
  end

  def get_parent(pid) do
    Agent.get(pid, fn %{parent: parent} -> parent end)
  end

  def get_state(pid) do
    Agent.get(pid, fn state -> state end)
  end
end
