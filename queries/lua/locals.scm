;; extends

; Scopes
[
  (chunk)
  (do_statement)
  (while_statement)
  (repeat_statement)
  (if_statement)
  (for_statement)
  (function_declaration)
  (function_definition)
] @local.scope

; Definitions
(assignment_statement
  (variable_list
    (identifier) @local.definition.var))

(assignment_statement
  (variable_list
    (dot_index_expression
      .
      (_) @local.definition.associated
      (identifier) @local.definition.var)))

((function_declaration
  name: (identifier) @local.definition.function)
  (#set! definition.function.scope "parent"))

((function_declaration
  name: (dot_index_expression
    .
    (_) @local.definition.associated
    (identifier) @local.definition.function))
  (#set! definition.method.scope "parent"))

((function_declaration
  name: (method_index_expression
    .
    (_) @local.definition.associated
    (identifier) @local.definition.method))
  (#set! definition.method.scope "parent"))

(for_generic_clause
  (variable_list
    (identifier) @local.definition.var))

(for_numeric_clause
  name: (identifier) @local.definition.var)

(parameters
  (identifier) @local.definition.parameter)

; References
(identifier) @local.reference

; Plugin Setup Blocks and Autocommands
((function_call
  name: [
    (dot_index_expression
      table: (function_call
        name: (identifier) @_req (#eq? @_req "require"))
      field: (identifier) @_setup (#eq? @_setup "setup"))
    (method_index_expression
      table: (function_call
        name: (identifier) @_req (#eq? @_req "require"))
      method: (identifier) @_setup (#eq? @_setup "setup"))
  ]) @local.definition.function
  (#set! definition.function.scope "parent")
  (#set! _init_lua_picker_setup true))

((function_call
  name: (dot_index_expression
    field: (identifier) @_autocmd (#eq? @_autocmd "nvim_create_autocmd"))) @local.definition.function
  (#set! definition.function.scope "parent")
  (#set! _init_lua_picker_setup true))

