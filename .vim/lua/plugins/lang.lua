return {
  -- JavaScript/TypeScript
  { "moll/vim-node", ft = "javascript" },
  { "yuezk/vim-js", ft = { "javascript", "javascriptreact" } },
  { "HerringtonDarkholme/yats.vim", ft = { "typescript", "typescriptreact" } },
  { "maxmellon/vim-jsx-pretty", ft = { "javascriptreact", "typescriptreact" } },
  { "leafgarland/typescript-vim", ft = "typescript" },
  { "David-Kunz/jester", ft = { "javascript", "typescript" } },
  { "mxw/vim-jsx", ft = "javascriptreact" },
  { "neoclide/vim-jsx-improve" },

  -- HTML/CSS
  { "JulesWang/css.vim", ft = "css" },
  { "tpope/vim-haml", ft = "haml" },
  { "othree/html5.vim", ft = "html" },
  { "alvan/vim-closetag", 
    ft = { "html", "xhtml", "phtml", "javascriptreact", "typescriptreact" },
    init = function()
      vim.g.closetag_filenames = "*.html.erb,*.html,*.xhtml,*.phtml"
    end,
  },
  { "hail2u/vim-css3-syntax", ft = "css" },
  { "cakebaker/scss-syntax.vim", ft = "scss" },

  -- Python
  { "nvie/vim-flake8", ft = "python" },
  { "Vimjas/vim-python-pep8-indent", ft = "python" },
  { "tweekmonster/django-plus.vim", ft = { "python", "django" } },

  -- Clojure
  { "clojure-vim/async-clj-omni", ft = "clojure" },
  { "tpope/vim-classpath", ft = "clojure" },
  { "guns/vim-clojure-static", ft = "clojure" },
  { "luochen1990/rainbow",
    ft = "clojure",
    config = function()
      vim.g.rainbow_active = 1
    end,
  },

  -- Go
  { "sebdah/vim-delve", ft = "go" },
  {
    "fatih/vim-go",
    ft = "go",
    config = function()
      vim.g.go_highlight_functions = 1
      vim.g.go_highlight_types = 1
    end,
  },

  -- Terraform
  { "hashivim/vim-terraform", ft = "terraform" },
  { "juliosueiras/vim-terraform-completion", ft = "terraform" },

  -- Other Languages
  { "Glench/Vim-Jinja2-Syntax", ft = "jinja" },
  { "tomlion/vim-solidity", ft = "solidity" },
  { "elixir-editors/vim-elixir", ft = "elixir" },
} 