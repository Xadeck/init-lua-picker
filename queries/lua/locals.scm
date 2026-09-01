;; extends

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
