require('luasnip.session.snippet_collection').clear_snippets 'typescriptreact'
local ls = require 'luasnip'

local snip = ls.snippet
local node = ls.snippet_node
local text = ls.text_node
local insert = ls.insert_node
local func = ls.function_node
local choice = ls.choice_node
local dynamicn = ls.dynamic_node

local date = function()
  return { os.date '%Y-%m-%d' }
end

local return_filename = function()
  return vim.fn.fnamemodify(vim.fn.expand '%', ':t')
end

ls.add_snippets('typescriptreact', {
  snip('naf', {
    text 'function ',
    func(return_filename),
    text '() { }',
  }),
})

return {}
