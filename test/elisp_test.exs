defmodule ElispTest do
  use ExUnit.Case
  alias Elisp.{Env, BinOp}

  test "should parse binary operations" do
    expression = "(+ 1 1)"
    result = Elisp.parse(expression)
    expected = {%BinOp{value: :add}, {1, {1, {nil, nil}}}}

    assert result == expected
  end

  test "should evaluate binary operation" do
    expression = "(+ 1 1)"
    result = Elisp.parse(expression) |> Elisp.evalrec(Env.start_link())
    expected = 2

    assert result == expected
  end

  test "should evaluate binary predicates" do
    expression = "(> 2 1)"
    result = Elisp.parse(expression) |> Elisp.evalrec(Env.start_link())
    expected = true

    assert result == expected
  end

  test "should evaluate cond expression (truthy case)" do
    expression = "(cond (> 4 2) (+ 4 2) (* 4 2))"
    result = Elisp.parse(expression) |> Elisp.evalrec(Env.start_link())
    expected = 6

    assert result == expected
  end

  test "should evaluate cond expression (falsy case)" do
    expression = "(cond (< 4 2) (+ 4 2) (* 4 2))"
    result = Elisp.parse(expression) |> Elisp.evalrec(Env.start_link())
    expected = 8

    assert result == expected
  end
end
