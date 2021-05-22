
# vim-grizzly

This plugin provides to complete from terminal histories using `+popupwin` feature and permanently save your histories.  
This is useful when your terminal(e.g. cmd.exe) does not permanently save your histories.  

## Usage

Use `Ctrl-n` or `Ctrl-p` In a terminal buffer.

## Variables

### g:grizzly\_prompt\_pattern (default: `has('win32') ? '^[A-Z]:\\.*>\zs.*' : '^[\$#]\zs.*'`)
This is a pattern of prompt.  

### g:grizzly\_history (default: `'~/.grizzly_history'`)
This is a path to save histories.  

## Screenshots

### cmd.exe
![](https://raw.githubusercontent.com/rbtnn/vim-grizzly/main/cmd.jpg)

### bash
![](https://raw.githubusercontent.com/rbtnn/vim-grizzly/main/bash.jpg)

## Installation
This is an example of installation using [vim-plug](https://github.com/junegunn/vim-plug).

```
Plug 'rbtnn/vim-grizzly'
```

## Requirements
* Vim must be compiled with `+popupwin` feature

## License
Distributed under MIT License. See LICENSE.

