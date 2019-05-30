defimpl String.Chars, for: Symbol do
  def to_string(symbol), do: symbol.value
end

defimpl String.Chars, for: SpecialForm do
  def to_string(se), do: se.value
end

defmodule Symbol do
  defstruct value: nil
end

defmodule BinOp do
  defstruct value: nil
end

defmodule BinPred do
  defstruct value: nil
end

defmodule SpecialForm do
  defstruct value: nil
end

defmodule Elisp do
  @cons_signature_funs %{
    Function => [Kernel, :is_function],
    Tuple => [Kernel, :is_tuple]
  }
  @cons_list_class Tuple
  @keywords_vk %{
    %BinOp{value: :add} => "+",
    %BinOp{value: :sub} => "-",
    %BinOp{value: :mul} => "*",
    %BinOp{value: :div} => "/",
    %BinOp{value: :mod} => "mod",
    %BinOp{value: :sconcat} => "++",
    %BinPred{value: :gt} => ">",
    %BinPred{value: :gte} => ">=",
    %BinPred{value: :lt} => "<",
    %BinPred{value: :lte} => "<=",
    %BinPred{value: :eq} => "=",
    %BinPred{value: :noeq} => "/=",
    %SpecialForm{value: :quote} => "quote",
    %SpecialForm{value: :typeof} => "typeof",
    %SpecialForm{value: :cons} => "cons",
    %SpecialForm{value: :car} => "car",
    %SpecialForm{value: :cdr} => "cdr",
    %SpecialForm{value: :cond} => "cond",
    %SpecialForm{value: :print} => "print",
    %SpecialForm{value: :read} => "read",
    %SpecialForm{value: :eval} => "eval",
    %SpecialForm{value: :def} => "def",
    %SpecialForm{value: :set} => "set!",
    %SpecialForm{value: :get} => "get",
    %SpecialForm{value: :evalin} => "eval-in",
    %SpecialForm{value: :lambda} => "lambda",
    %SpecialForm{value: :macro} => "macro",
    %SpecialForm{value: :macroexpand} => "macroexpand"
  }

  @keywords_kv Enum.map(@keywords_vk, fn {k, v} -> {v, k} end) |> Enum.into(%{})

  defguard is_none(l) when l == {nil, nil}

  def cons(a, b), do: {a, b}

  def car(l), do: elem(l, 0)

  def cdr(l), do: elem(l, 1)

  def none, do: cons(nil, nil)

  def is_none?({nil, nil}), do: true
  def is_none?(_), do: false

  def is_conslist(o) do
    [m, f] = @cons_signature_funs[@cons_list_class]
    apply(m, f, [o])
  end

  def get_type_name(o) do
    cond do
      is_number(o) -> "Number"
      is_binary(o) -> "String"
      is_conslist(o) -> "ConsList"
      is_boolean(o) -> "Boolean"
    end
  end

  def prslist(s) do
    cond do
      String.trim(s) == "" ->
        raise "Closed ')' is absent"

      String.first(s) == ")" ->
        {none(), String.slice(s, 1..-1)}

      true ->
        {x, ss} = prs(s)
        {t, zz} = prslist(ss)
        {cons(x, t), zz}
    end
  end

  def prsval("true"), do: true
  def prsval("false"), do: false

  def prsval(s) do
    if Map.has_key?(@keywords_kv, s) do
      @keywords_kv[s]
    else
      case Integer.parse(s) do
        {int, _} ->
          int

        _ ->
          case Float.parse(s) do
            {float, _} -> float
            _ -> %Symbol{value: s}
          end
      end
    end
  end

  def prs(str) do
    s = String.trim(str)
    rest_s = String.slice(s, 1..-1)

    cond do
      String.trim(s) == "" ->
        {none(), ""}

      String.starts_with?(s, "(") ->
        prslist(rest_s)

      String.starts_with?(s, ")") ->
        raise "Extra closed ')'"

      String.starts_with?(s, "\"") ->
        case String.split(rest_s, "\"", parts: 2) do
          [_] -> raise "Closed \" is absent"
          [head, tail] -> {head, tail}
        end

      String.starts_with?(s, ";") ->
        case String.split(rest_s, ";", parts: 2) do
          [_] -> raise "Closed ; is absent"
          [_, tail] -> prs(tail)
        end

      String.starts_with?(s, "'") ->
        {x, ss} = prs(rest_s)
        {cons(%SpecialForm{value: :quote}, cons(x, none())), ss}

      true ->
        [{a, _} | _] = Regex.run(~r{\s|\(|\)|\"|;|$}, s, return: :index)
        {prsval(String.slice(s, 0, a)), String.slice(s, a..-1)}
    end
  end

  def parse(s) do
    {x, ss} = prs(s)

    if String.trim(ss) == "" do
      x
    else
      {y, zz} = prs(Enum.join(["(", ss, ")"], ""))

      if String.trim(zz) == "" do
        cons(x, y)
      else
        raise "Extra symbols"
      end
    end
  end

  def show(:cons, o, acc) when is_none(o), do: Enum.join(["(", String.trim(acc), ")"], "")
  def show(:cons, o, acc), do: show(:cons, cdr(o), Enum.join([acc, show(car(o))], " "))
  def show(o) when is_binary(o), do: Enum.join(["\"", o, "\""], "")
  def show(o) when is_boolean(o), do: if(o, do: 'true', else: 'false')
  def show(o) when is_number(o), do: o
  def show(o) when is_none(o), do: nil
  def show(%Symbol{value: v}), do: v

  def show(o) do
    cond do
      is_conslist(o) -> show(:cons, o, "")
      Map.has_key?(@keywords_vk, o) -> @keywords_vk[o]
    end
  end

  def bo(op, a, b) do
    case op do
      :add -> a + b
      :sub -> a - b
      :mul -> a * b
      :div -> a / b
      :mod -> rem(a, b)
      :sconcat -> "#{a}#{b}"
      _ -> nil
    end
  end

  def foldbo(_, o) when is_none(o), do: raise("no operands for arithmetic operation")

  def foldbo(op, {head, tail}) do
    res = evalrec(head)
    foldbo(op, tail, res)
  end

  def foldbo(_, o, acc) when is_none(o), do: acc

  def foldbo(op, {head, tail}, acc) do
    foldbo(op, tail, bo(op, acc, evalrec(head)))
  end

  def bp(op, a, b) do
    case op do
      :gt -> a > b
      :gte -> a >= b
      :lt -> a < b
      :lte -> a <= b
      :eq -> a == b
      :noeq -> a != b
      _ -> nil
    end
  end

  def foldbp(_, o) when is_none(o), do: raise("no operands for arithmetic operation")

  def foldbp(op, {head, tail}) do
    res = evalrec(head)
    foldbp(op, tail, res)
  end

  def foldbp(_, o, _) when is_none(o), do: true

  def foldbp(op, {head, tail}, acc) do
    case bp(op, acc, evalrec(head)) do
      false -> false
      true -> foldbp(op, tail, head)
    end
  end

  def fold_list(o) when is_none(o), do: o

  def fold_list(o) do
    cons(evalrec(car(o)), fold_list(cdr(o)))
  end

  def eval_cond({head, tail} = t) when not is_none(t) and not is_none(tail) do
    cond do
      evalrec(head) -> evalrec(car(tail))
      true -> eval_cond(cdr(tail))
    end
  end

  def eval_cond(t) when is_none(t), do: none()
  def eval_cond({head, _}), do: evalrec(head)

  def apply_special_form(form, args) do
    case form do
      :quote ->
        car(args)

      :typeof ->
        get_type_name(evalrec(car(args)))

      :cons ->
        cons(evalrec(car(args)), fold_list(cdr(args)))

      :car ->
        a = evalrec(car(args))

        cond do
          is_conslist(a) -> car(a)
          true -> a
        end

      :cdr ->
        a = evalrec(car(args))

        cond do
          is_conslist(a) -> cdr(a)
          true -> none()
        end

      :cond ->
        eval_cond(args)

      :print ->
        IO.puts(cons(%BinOp{value: :sconcat}, fold_list(args)) |> evalrec)
        none()

      :read ->
        inp = IO.gets(cons(%BinOp{value: :sconcat}, fold_list(args)) |> evalrec)
        parse(inp)

      :eval ->
        evalrec(evalrec(car(args)))

      _ ->
        raise("Undefined special form")
    end
  end

  def evalrec(o) when is_none(o), do: o

  def evalrec({head, tail}) do
    case head do
      %BinOp{value: op} -> foldbo(op, tail)
      %BinPred{value: pred} -> foldbp(pred, tail)
      %SpecialForm{value: form} -> apply_special_form(form, tail)
      _ -> {head, tail}
    end
  end

  def evalrec(o), do: o

  def repl() do
    input = IO.gets(">>> ")

    case input do
      ":q\n" ->
        IO.puts("Bye!")

      inp ->
        inp
        |> parse
        |> evalrec
        |> show
        |> IO.inspect()

        repl()
    end
  end
end
