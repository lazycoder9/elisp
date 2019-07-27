# Elisp
 LISP interpreter in Elixir

 Work in progress

 Requirements: `elixir ~> 1.8.0`

 Usage
 ```
 mix escript.build
 ./elisp
 ````

 Interpreter will run in repl mode and you can execute simple S-expressions
 ```
 >>> (+ 1 1)
 2
 >>> (def a 10)
 :ok
 >>> (* a 2)
 20
 >>> (def double (lambda (x) (* x 2)))
 :ok
 >>> (double 20)
 40
 >>> (double a)
 20
 ```
