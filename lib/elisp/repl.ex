defmodule Elisp.Repl do
  alias Elisp.Env

  def main(_args) do
    {:ok, env} = Env.start()
    repl(env)
  end

  def repl(env) do
    IO.gets(">>> ")
    |> execute(env)
  end

  def execute(":q\n", _) do
    IO.puts("Bye!")
  end

  def execute(expression, env) do
    units = :microsecond
    start = System.monotonic_time(units)

    expression
    |> Elisp.parse()
    |> Elisp.evalrec(env)
    |> Elisp.show()
    |> IO.inspect()

    time_spent = System.monotonic_time(units) - start
    IO.puts("Executed in #{time_spent / 1_000_000} seconds")
    repl(env)
  end
end
