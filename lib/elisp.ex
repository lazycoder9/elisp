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

defmodule Lambda do
  defstruct [:args, :body, :env]
end

defmodule Elisp do
  alias Elisp.Env

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

  def get_body(o) do
    cond do
      is_conslist(o) and !is_none(o) and is_none(cdr(o)) -> car(o)
      true -> o
    end
  end

  def get_type_name(%Lambda{}), do: "Lambda"

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
  def show(%Lambda{args: args, body: body}), do: "(lambda #{show(args)} #{show(body)})"

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

  def foldbo(op, {head, tail}, env) do
    res = evalrec(head, env)
    foldbo(op, tail, res, env)
  end

  def foldbo(_, o, acc, _) when is_none(o), do: acc

  def foldbo(op, {head, tail}, acc, env) do
    foldbo(op, tail, bo(op, acc, evalrec(head, env)), env)
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

  def foldbp(_, o, _) when is_none(o), do: raise("no operands for arithmetic operation")

  def foldbp(op, {head, tail}, env) do
    res = evalrec(head, env)
    foldbp(op, tail, res, env)
  end

  def foldbp(_, o, _, _) when is_none(o), do: true

  def foldbp(op, {head, tail}, acc, env) do
    case bp(op, acc, evalrec(head, env)) do
      false -> false
      true -> foldbp(op, tail, head, env)
    end
  end

  def fold_list(o, _) when is_none(o), do: o
  def fold_list(o, env), do: cons(evalrec(car(o), env), fold_list(cdr(o), env))

  def eval_cond({head, tail} = t, env) when not is_none(t) and not is_none(tail) do
    cond do
      evalrec(head, env) -> evalrec(car(tail), env)
      true -> eval_cond(cdr(tail), env)
    end
  end

  def eval_cond(t, _) when is_none(t), do: none()
  def eval_cond({head, _}, env), do: evalrec(head, env)

  def object_eval_to_symbol(%Symbol{value: value}, _), do: value
  def object_eval_to_symbol(s, _) when is_binary(s), do: s

  def object_eval_to_symbol(o, env) do
    s = evalrec(o, env) |> show

    if String.starts_with?(s, "\"") and String.last(s) == "\"" do
      String.slice(s, 1..-2)
    else
      s
    end
  end

  def get_map_names_values(ns, bs, env, eval_flag),
    do: get_map_names_values(ns, bs, env, eval_flag, %{})

  def get_map_names_values(ns, bs, _, _, acc) when is_none(ns) and is_none(bs), do: acc

  def get_map_names_values(ns, bs, env, eval_flag, acc) do
    v =
      cond do
        is_none?(cdr(ns)) and !is_none?(cdr(bs)) ->
          if(eval_flag, do: fold_list(bs, env), else: bs)

        true ->
          if(eval_flag, do: evalrec(car(bs), env), else: car(bs))
      end

    %Symbol{value: value} = car(ns)
    get_map_names_values(cdr(ns), cdr(bs), env, eval_flag, Map.put_new(acc, value, v))
  end

  def apply_special_form(form, args, env) do
    case form do
      :quote ->
        car(args)

      :typeof ->
        get_type_name(evalrec(car(args), env))

      :cons ->
        cons(evalrec(car(args), env), fold_list(cdr(args), env))

      :car ->
        a = evalrec(car(args), env)

        cond do
          is_conslist(a) -> car(a)
          true -> a
        end

      :cdr ->
        a = evalrec(car(args), env)

        cond do
          is_conslist(a) -> cdr(a)
          true -> none()
        end

      :cond ->
        eval_cond(args, env)

      :def ->
        Env.def_var(env, object_eval_to_symbol(car(args), env), evalrec(car(cdr(args)), env))
        |> repl

      :set ->
        Env.set_var(env, object_eval_to_symbol(car(args), env), evalrec(car(cdr(args)), env))
        |> repl

      :get ->
        s = car(args)
        Env.get_var(env, object_eval_to_symbol(s, env), s)

      :lambda ->
        %Lambda{args: car(args), body: get_body(cdr(args)), env: env}

      :print ->
        IO.puts(cons(%BinOp{value: :sconcat}, fold_list(args, env)) |> evalrec(env))
        none()

      :read ->
        inp = IO.gets(cons(%BinOp{value: :sconcat}, fold_list(args, env)) |> evalrec(env))
        parse(inp)

      :eval ->
        evalrec(evalrec(car(args), env), env)

      _ ->
        raise("Undefined special form")
    end
  end

  def evalrec(o, _) when is_none(o), do: o

  def evalrec(%Symbol{value: value} = o, env), do: Env.get_var(env, value, o)

  # def evalrec(%Lambda{args: args, body: body, env: e}, env),
  #   do: evalrec(body, %Env{frame: get_map_names_values(args, tail, env, true), parent: e})

  def evalrec({head, tail}, env) do
    h = evalrec(head, env)

    case h do
      %BinOp{value: op} ->
        foldbo(op, tail, env)

      %BinPred{value: pred} ->
        foldbp(pred, tail, env)

      %SpecialForm{value: form} ->
        apply_special_form(form, tail, env)

      %Lambda{args: args, body: body, env: e} ->
        map = get_map_names_values(args, tail, env, true)
        # require IEx
        # IEx.pry()
        evalrec(body, Env.start_link(e, map))

      _ ->
        eval_list(h, tail, env)
    end
  end

  def evalrec(o, _), do: o

  def eval_list(h, t, _) when is_none(t), do: t

  def eval_list(_, t, env) do
    eval_list(evalrec(car(t), env), cdr(t), env)
  end

  def repl(), do: repl(Env.start_link())

  def repl(env) do
    input = IO.gets(">>> ")

    case input do
      ":q\n" ->
        IO.puts("Bye!")

      inp ->
        inp
        |> parse
        |> evalrec(env)
        |> show
        |> IO.inspect()

        repl(env)
    end
  end
end
