# TreePin

---
A lightweight neovim plugin for pinning fragments of code to
the screen.

## Install

---
### Lazy
```
{
	'KaitlynEthylia/TreePin',
	dependencies = 'nvim-treesitter/nvim-treesitter',
	init = function() require('treepin').setup() end,
}
```

### Packer
```lua
use {
	'KaitlynEthylia/TreePin',
	requires = {'nvim-treesitter/nvim-treesitter'},
	config = function() require('treepin').setup() end,
}
```

### Plug
```lua
Plug 'nvim-treesitter/nvim-treesitter'
Plug 'KaitlynEthylia/TreePin'
```

## Demo

---
![demo](./static/demo.gif)

## Setup

---
Treepin will do nothing until the setup function is called.
The setup function may be called with no args, or a table
of configuration options, the default configuration is
shown below.

```lua
require('treepin').setup {
	hide_onscreen = true, -- Hide's the pin buffer when the text of the pin is visible.
	max_height = 30, -- Prevents the pin buffer from displaying when the pin is larger than x lines.
	position = 'relative', -- May be 'relative', 'top', or 'bottom'. Determines the position of the pin buffer within the window.
	icon = '>', -- The icon to display in the sign column at the top of the pin. Set to nil to prevent the sign column being used.
	zindex = 50, -- The Z-index of the pin buffer.
	seperator = nil, -- A single character that may be used as a seperator between the editing buffer and the pin buffer.
}
```

## Commands

---
| Command | Lua Function | Description |
| ------- | ------------ | ----------- |
| TPPin | `treepin.pinLocal()` | Sets the window's pin at the treesitter node under the cursor. |
| TPRoot | `treepin.pinRoot()` | Sets the window's pin at the second largest treesitter node under the cursor (the largest is the file itself). |
| TPGrow | `treepin.pinGrow()` | Expands the pin to the next parent treesitter node that sits on a different line. |
| TPShrink | `treepin.pinShrink()` | Reverses the effect of growing the pin. Cannot be shrunk smaller than the node under the cursor when the pin was created. |
| TPClear | `treepin.pinClear()` | Removes the pin buffer and the pin itself. |
| TPGo | `treepin.pinGo()` | Jump to the first line of the pin. |
| TPShow | `treepin.pinShow()` | Called automatically when a pin is created. Enables displaying the pin buffer. |
| TPHide | `treepin.pinHide()` | Hides the pin buffer but keeps the pin stored. |

Although there is no user command for it, the
`treepin.pin(winnr, base, grow, bufnr)` function is also
available for anyone who want's to create an arbitrary pin
in script. The arguments are detailed in doc comments.

Keybindings are down to the user to set themselvs.

## Future

---

Several features have already been considered for future
versions, particularly:

 - More scripting utilities in order to integrate with
 other tools better.
 - The ability to save pin history and jump between them.
 If this is implemented it may be its own plugin
 - The ability to move the pin to adjacent treesitter nodes.

### Note
These are not promises. The first one is very
likely to happen however as it alone could introduce the
ability for external code to implement the others.

## Contributing

---
All contributions are welcome! Just follow common sense
ettiquete and we can create something that works.
