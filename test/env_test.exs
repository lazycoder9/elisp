defmodule EnvTest do
  use ExUnit.Case
  alias Elisp.Env

  test "example" do
    {:ok, env} = Env.start_link()
    {:ok, env2} = Env.start_link(env)

    test_key = :x
    test_value = 42

    Env.def_var(env, test_key, test_value)
    assert test_value == Env.get_var(env, test_key, test_key)
  end
end
