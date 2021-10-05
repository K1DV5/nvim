-- init script in lua (WIP)

local fn = vim.fn
local install_path = fn.stdpath('data') .. '/site/pack/paqs/start/paq-nvim'
if fn.empty(fn.glob(install_path)) > 0 then
  fn.system({'git', 'clone', '--depth=1', 'https://github.com/savq/paq-nvim.git', install_path})
end

-- setup packages only if they exist, to not prevent loading other parts
local function setup(name, config, setup_func)
    if config == nil then
        config = {}
    end
    if setup_func == nil then
        setup_func = 'setup'
    end
    local exists, package = pcall(require, name)
    if exists then
        if package[setup_func] == nil then
            print(name .. '.' .. setup_func, 'not found')
        else
            package[setup_func](config)
        end
    else
        print('package', name, 'not found')
    end
end

require "paq" {
    "savq/paq-nvim";                  -- Let Paq manage itself

    "neovim/nvim-lspconfig"; -- config in lsp.lua

    "hrsh7th/nvim-cmp";
    (function()
        local cmp = require'cmp'
        local luasnip = require'luasnip'
        cmp.setup{
            formatting = {
                format = function(entry, vim_item)
                    return vim_item
                end,
            },
            mapping = {
                ['<CR>'] = cmp.mapping.confirm({
                    behavior = cmp.ConfirmBehavior.Insert,
                    select = true,
                })
            },
            snippet = {
                expand = function(args)
                    luasnip.lsp_expand(args.body)
                end
            },
            sources = { -- You should specify your *installed* sources.
              {name = 'nvim_lsp'},
              {name = 'luasnip'},
              {name = 'buffer'},
            },
        }
        -- require("nvim-autopairs.completion.cmp").setup({
        --   map_cr = true, --  map <CR> on insert mode
        --   map_complete = true, -- it will auto insert `(` after select function or method item
        -- })
    end)();

    "hrsh7th/cmp-buffer";
    "hrsh7th/cmp-nvim-lsp";

    "windwp/nvim-autopairs";
    setup('nvim-autopairs');

    "nvim-treesitter/nvim-treesitter";
        setup('nvim-treesitter.configs', {
            highlight = {
                enable = true,
                additional_vim_regex_highlighting = false,
            },
            incremental_selection = { enable = true },
            textobjects = { enable = true },
            rainbow = {
                enable = true,
            },
            context_commentstring = {
                enable = true
            },
            vim.cmd('set foldmethod=expr foldexpr=nvim_treesitter#foldexpr() foldlevel=99')
        });

    "blackCauldron7/surround.nvim";
    setup('surround', {
        mappings_style = "surround"
    });

    "kyazdani42/nvim-tree.lua";
        setup('nvim-tree', {
              (function()
                  vim.g.nvim_tree_window_picker_exclude = {filetype = {"packer", "qf", "Outline"}}
                  vim.g.nvim_tree_show_icons = {git = 0, folders = 1, files = 1, folder_arrows = 1}
              end)(),
              lsp_diagnostics     = true,
        });

    "kyazdani42/nvim-web-devicons";  -- pretty icons, for nvim-tree

    -- diagnostics window
    "folke/trouble.nvim";
    setup('trouble');

    "ggandor/lightspeed.nvim";  -- move fast in nvim

    "JoosepAlviste/nvim-ts-context-commentstring";

    "terrortylor/nvim-comment";
        setup('nvim_comment', {
            comment_empty = false
        });

    "Mofiqul/vscode.nvim"; -- vscode's dark+ theme
        (function()
            if vim.g.vscode_style == nil then
                vim.g.vscode_style = "dark"
                vim.cmd[[colorscheme vscode]]
            end
        end)();

    "L3MON4D3/LuaSnip";
    "saadparwaiz1/cmp_luasnip";

    "simrat39/symbols-outline.nvim";
        (function()
            vim.g.symbols_outline = {
                symbol_blacklist = {'Variable', 'Constant'},
            }
        end)();

    "jakewvincent/mkdnflow.nvim";
    setup('mkdnflow');

    {"camspiers/snap", run =
     'curl https://raw.githubusercontent.com/swarn/fzy-lua/main/src/fzy_lua.lua -o '
     .. fn.stdpath('config')
     ..  '/lua/fzy.lua'
     };
        (function()
            local snap = require'snap'
            snap.maps{
                {"-", snap.config.file {producer = "ripgrep.file", consumer = "fzy"}},
                -- {"<Leader>fb", snap.config.file {producer = "vim.buffer", consumer = "fzy"}},
                -- {"<Leader>fo", snap.config.file {producer = "vim.oldfile", consumer = "fzy"}},
                -- {"<Leader>ff", snap.config.vimgrep {consumer = "fzy"}},
            }
        end
        )();

    "hoob3rt/lualine.nvim";
    setup('lualine', {
        options = {
            theme = 'codedark',
            section_separators = {'', ''},
            component_separators = {'', ''},
            disabled_filetypes = {'Outline', 'NvimTree'},
        },
        sections = {
            lualine_a = {'mode'},
            lualine_b = {vim.fn.TabsStatusText},
            lualine_c = {},
            lualine_x = {'fileformat'},
            lualine_y = {
                'progress',
                {
                    'diagnostics',
                    symbols = {error = ' ', warn = ' ', info = ' ', hint = ' '},
                    -- all colors are in format #rrggbb
                    sources = {'nvim_lsp'},
                    color_error = 'red', -- changes diagnostic's error foreground color
                    color_warn = 'yellow', -- changes diagnostic's warn foreground color
                    color_info = 'green', -- Changes diagnostic's info foreground color
                    color_hint = 'cyan', -- Changes diagnostic's hint foreground color
                },
            },
            lualine_z = {'branch'},
        },
        inactive_sections = {
            lualine_a = {},
            lualine_b = {vim.fn.TabsStatusText},
            lualine_c = {},
            lualine_x = {},
            lualine_y = {},
            lualine_z = {},
        },
    });

    -- look for alternatives in lua
    "mattn/emmet-vim";
    "mbbill/undotree";
    "mhinz/vim-signify";
    "lambdalisue/gina.vim";
}

-- vim:foldmethod=marker:foldlevel=0
