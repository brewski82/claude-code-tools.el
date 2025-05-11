# claude-code-tools.el

Tools for working with [Claude Code](https://docs.anthropic.com/en/docs/agents-and-tools/claude-code/overview) within Emacs.

## Overview

This package provides a set of convenient functions for interacting with the Claude Code CLI from within Emacs. It allows you to:

- Open Claude Code sessions in a vterm buffer
- Support multiple, concurrent Claude Code sessions for different projects
- Send messages to Claude Code
- Send buffer contents, regions, or contextual information to Claude Code (including from Magit diff views)
- Execute one-shot commands using Claude Code
- Easily manage multiple Claude Code sessions

## Requirements

- Emacs 28.1 or later
- magit
- vterm
- The Claude Code CLI tool (`claude`) installed and available in your PATH

## Installation

### Manual Installation

Clone this repository:

```bash
git clone https://github.com/brewski82/claude-code-tools.el.git
```

Add the following to your Emacs configuration:

```elisp
(add-to-list 'load-path "/path/to/claude-code-tools.el")
(require 'claude-code-tools)
```

### Using package.el with vc-install (Emacs 30+)

```elisp
;; Install directly from GitHub
(package-vc-install '(claude-code-tools :url "https://github.com/brewski82/claude-code-tools.el"))

;; Then in your init.el:
(require 'claude-code-tools)
(global-set-key (kbd "C-c c") 'claude-code-tools-run-claude-code-menu) ;; or your preferred key
```

### Using straight.el

```elisp
(use-package claude-code-tools
  :straight (:type git :host github :repo "brewski82/claude-code-tools.el" :branch "main"
                   :files ("*.el" (:exclude ".gitignore")))
  :bind ("C-c c" . claude-code-tools-run-claude-code-menu)
  :config
  ;; Optional configuration here
  )
```

## Usage

### Interactive Commands

- `claude-code-tools-claude-code-vterm`: Open a Claude Code session in a vterm buffer
- `claude-code-tools-send-to-claude`: Send a message to Claude Code
- `claude-code-tools-send-to-claude-with-buffer`: Send the current buffer's content to Claude Code
- `claude-code-tools-send-to-claude-with-region`: Send the selected region to Claude Code
- `claude-code-tools-send-message-to-claude-with-context`: Send the current file name and line number to Claude Code (works with both regular files and Magit diff views)
- `claude-code-tools-one-shot`: Run a one-shot Claude Code command (uses `compile` in the project root, calling Claude in non-interactive mode)
- `claude-code-tools-open-in-new-worktree`: Create a new git worktree branch and open Claude Code in it
- `claude-code-tools-run-claude-code-menu`: Display a transient menu with all Claude Code commands

### Transient Menu

The easiest way to access all Claude Code commands is through the transient menu:

```elisp
M-x claude-code-tools-run-claude-code-menu
```

This will display a menu with the following options:

Commands:
- `s`: Send a message to Claude Code
- `b`: Send buffer contents to Claude Code
- `r`: Send region to Claude Code
- `c`: Send context (file and line number) to Claude Code
- `o`: Run a one-shot Claude Code command (uses `compile` in the project root, calling Claude in non-interactive mode)

Session:
- `O`: Open a Claude Code session
- `S`: Select an existing Claude Code session (assigns current buffer to a Claude session, useful for building complex prompts)
- `W`: Create a new git worktree and open Claude Code in it (calls `claude-code-tools-open-in-new-worktree`)

## Tips

### Removing Underlines for Non-breaking Spaces

If Emacs is displaying underlines for non-breaking spaces that you find distracting, you can add the following to your configuration:

```elisp
(set-face-attribute 'nobreak-space nil :underline nil)
```

### Fixing vterm Flickering

If you experience flickering in vterm buffers when using Claude Code, try setting the vterm timer delay to nil:

```elisp
(setq vterm-timer-delay nil)
```

### Fixing vterm Enter Key in Transient Menus

If you encounter issues where the Enter key doesn't work in transient menus when using vterm (error: "Unbound suffix: '<return>'"), you can fix this with the following configuration:

```elisp
(define-key vterm-mode-map [return] nil t)
```

This workaround resolves a bug where vterm's double definition of the return key breaks transient menu functionality. See [issue #765](https://github.com/akermu/emacs-libvterm/issues/765) for more details.

## Related Packages

This package was inspired by:

- [claude-code.el](https://github.com/stevemolitor/claude-code.el): Another package providing Claude Code integration, using eat for terminal emulation and offering comprehensive slash command integration via transient menus.

## License

MIT
