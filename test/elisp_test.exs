defmodule ElispTest do
  use ExUnit.Case
  alias Elisp.{Env, BinOp}

  setup do
    {:ok, env} = Env.start_link()
    {:ok, evaluate: fn expr -> Elisp.parse(expr) |> Elisp.evalrec(env) end}
  end

  test "should parse binary operations" do
    expression = "(+ 1 1)"
    result = Elisp.parse(expression)
    expected = {%BinOp{value: :add}, {1, {1, {nil, nil}}}}

    assert result == expected
  end

  test "should evaluate binary operation", context do
    expression = "(+ 1 1)"
    result = context[:evaluate].(expression)
    expected = 2

    assert result == expected
  end

  test "should evaluate binary predicates", context do
    expression = "(> 2 1)"
    result = context[:evaluate].(expression)
    expected = true

    assert result == expected
  end

  test "should evaluate cond expression (truthy case)", context do
    expression = "(cond (> 4 2) (+ 4 2) (* 4 2))"
    result = context[:evaluate].(expression)
    expected = 6

    assert result == expected
  end

  test "should evaluate cond expression (falsy case)", context do
    expression = "(cond (< 4 2) (+ 4 2) (* 4 2))"
    result = context[:evaluate].(expression)
    expected = 8

    assert result == expected
  end

  test "should define variable", context do
    expression = "(def a 10) a"

    result = context[:evaluate].(expression)
    expected = 10

    assert result == expected
  end

  test "should define and evaluate lambda expressions", context do
    expression = "(def f (lambda (x) (* x 2))) (f 10)"
    result = context[:evaluate].(expression)
    expected = 20

    assert result == expected
  end

  test "should use variables in lambda expressions", context do
    expression = "(def f (lambda (x) (* 2 (+ x 2)))) (def a 20) (f a)"
    result = context[:evaluate].(expression)
    expected = 44

    assert result == expected
  end

  test "should set variable", context do
    expression = "(def a 10) (set! a 20) a"
    result = context[:evaluate].(expression)
    expected = 20

    assert result == expected
  end
end
