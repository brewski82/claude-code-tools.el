;;; claude-code-tools.el --- Tools for working with Claude Code  -*- lexical-binding: t; -*-

;; Copyright (C) 2025  William Bruschi

;; Author: William Bruschi
;; Keywords: tools, convenience
;; Version: 0.1.0
;; Package-Requires: ((emacs "28.1") (magit "3.0") (vterm "0.0.1") (transient "0.3.7") (project "0.9.8"))
;; URL: https://github.com/brewski82/claude-code-tools.el

;; Permission is hereby granted, free of charge, to any person obtaining a copy
;; of this software and associated documentation files (the "Software"), to deal
;; in the Software without restriction, including without limitation the rights
;; to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
;; copies of the Software, and to permit persons to whom the Software is
;; furnished to do so, subject to the following conditions:

;; The above copyright notice and this permission notice shall be included in all
;; copies or substantial portions of the Software.

;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
;; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
;; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
;; AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
;; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
;; OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
;; SOFTWARE.

;;; Commentary:

;; This package provides tools for working with Claude Code within Emacs.
;; It includes commands to send code selections to Claude Code and process
;; the results.
;;
;; Key features include:
;; - Running Claude Code in vterm buffers within Emacs
;; - Support for multiple concurrent Claude sessions for different projects
;; - Sending buffer contents, regions, or contextual information to Claude
;; - Support for Magit diff views when sending context to Claude
;; - Non-interactive "one-shot" mode for quick queries
;; - Multiple session management through a transient menu interface
;;
;; See the README.md for more comprehensive documentation and usage examples.

;;; Code:

(require 'magit)
(require 'vterm)
(require 'project)
(require 'transient)

;;;; Customization

(defgroup claude-code-tools nil
  "Tools for working with Claude Code within Emacs."
  :group 'tools
  :prefix "claude-code-tools-"
  :link '(url-link :tag "GitHub" "https://github.com/brewski82/claude-code-tools.el"))

(defcustom claude-code-tools-default-claude-command "claude"
  "The command used to launch Claude Code."
  :type 'string
  :group 'claude-code-tools)

(defcustom claude-code-tools-oneshot-args "-p"
  "Arguments to pass to Claude Code for one-shot (non-interactive) mode."
  :type 'string
  :group 'claude-code-tools)

(defvar-local claude-code-tools-claude-code-buffer-name-local nil
  "Buffer-local variable to store the claude code buffer name.")

;;;; Main user-facing commands

;;;###autoload
(defun claude-code-tools-run-claude-code-menu ()
  "Launch the interactive Claude Code command menu.

Displays a transient menu with all available Claude Code
commands, organized into command and session management sections.
This is the recommended entry point for using Claude Code tools."
  (interactive)
  (claude-code-tools-claude-transient))

;;;###autoload
(defun claude-code-tools-claude-code-vterm ()
  "Open or switch to a Claude Code session in a vterm buffer.

If a Claude Code buffer already exists for the current project,
switches to it. Otherwise, creates a new vterm buffer named after
the project, launches Claude Code in the project root directory,
and initializes a new interactive session."
  (interactive)
  (let ((claude-buffer (claude-code-tools-current-claude-code-buffer-name)))
    (if (get-buffer claude-buffer)
        (switch-to-buffer claude-buffer)  ; Switch to existing buffer
      (let* ((project-directory (project-root (project-current)))
             (default-directory project-directory)
             (buffer (vterm claude-buffer)))
        (with-current-buffer buffer
          (vterm-insert claude-code-tools-default-claude-command)
          (vterm-send-return))))))

;;;###autoload
(defun claude-code-tools-open-in-new-worktree ()
  "Create a new git worktree and open Claude Code in it.

First creates a new git worktree branch using magit, then opens a
Claude Code session in the newly created worktree."
  (interactive)
  (call-interactively 'magit-worktree-branch)
  (claude-code-tools-claude-code-vterm))

;;;###autoload
(defun claude-code-tools-set-claude-code-buffer-name ()
  "Interactively select a Claude Code buffer for the current buffer.

Prompts user to select from existing buffers and associates the
current buffer with the selected Claude session. This enables
sending content from the current buffer to a specific Claude
session, allowing for complex prompt building."
  (interactive)
  (let* ((buffers (mapcar 'buffer-name (buffer-list)))
         (selected-buffer (completing-read "Select buffer: " buffers)))
    (setq claude-code-tools-claude-code-buffer-name-local selected-buffer)
    (message "Set claude code buffer name to: %s" selected-buffer)))

;;;###autoload
(defun claude-code-tools-create-buffer-for-current-session ()
  "Create a new buffer and set its Claude session to the current
project.

Creates a new buffer named 'claude-prompt-PROJECT' and associates
it with the Claude Code session of the current project. This is
useful for preparing complex prompts across multiple buffers for
the same Claude session."
  (interactive)
  (let* ((project-name (file-name-nondirectory
                        (directory-file-name
                         (project-root (project-current)))))
         (buffer-name (format "claude-prompt-%s" project-name))
         (claude-buffer (claude-code-tools-current-claude-code-buffer-name))
         (new-buffer (get-buffer-create buffer-name)))
    (switch-to-buffer new-buffer)
    (setq claude-code-tools-claude-code-buffer-name-local claude-buffer)
    (message "Created buffer %s associated with Claude session %s"
             buffer-name claude-buffer)))

;;;###autoload
(defun claude-code-tools-send-to-claude ()
  "Interactively send a plain text message to Claude Code.

Prompts for a message and sends it to the current Claude Code
session. Use this when you want to ask a question or give an
instruction without including any buffer content or context."
  (interactive)
  (let ((message (read-string "Enter message: ")))
    (claude-code-tools-send-message-to-claude message)))

;;;###autoload
(defun claude-code-tools-send-to-claude-with-buffer ()
  "Send the entire contents of the current buffer to Claude Code.

Prompts for an additional message to append after the buffer
contents. Useful for asking Claude to analyze, refactor, or
explain the code in the current buffer."
  (interactive)
  (let* ((user-message (read-string "Enter message: "))
         (buffer (claude-code-tools-current-claude-code-buffer-name))
         (buffer-contents (buffer-string))
         (message (concat buffer-contents "\n\n" user-message)))
    (claude-code-tools-send-message-to-claude message)))

;;;###autoload
(defun claude-code-tools-send-to-claude-with-region ()
  "Send the currently selected region to Claude Code.

Prompts for an additional message to append after the region
text. Useful for asking Claude to work with a specific section of
code without sending the entire buffer."
  (interactive)
  (if (use-region-p)
      (let* ((user-message (read-string "Enter message: "))
             (region-text (buffer-substring-no-properties (region-beginning) (region-end)))
             (final-message (concat region-text "\n\n" user-message)))
        (claude-code-tools-send-message-to-claude final-message))
    (message "No region selected.")))

;;;###autoload
(defun claude-code-tools-send-message-to-claude-with-context ()
  "Send file path and line context information to Claude Code.

Works in both regular file buffers and Magit diff buffers.
Extracts the file name, current line number, and (for diffs) the
number of lines in the current hunk. This provides Claude with
precise location information for answering questions about
specific code locations."
  (interactive)
  (let* ((user-message (read-string "Enter message: "))
         (file (or (buffer-file-name)
                    (magit-file-at-point)))
         (line (if (buffer-file-name)
                   (line-number-at-pos)
                 (car (claude-code-tools-magit-diff-get-line-number))))
         (line-count (if (buffer-file-name)
                         0
                       (cdr (claude-code-tools-magit-diff-get-line-number))))
         (final-message (concat "File name: " file "\n\n"
                                "line number: " (number-to-string line) "\n\n"
                                (when (not (eq line-count 0))
                                  (concat "line count: " (number-to-string line-count) "\n\n"))
                                user-message)))
    (if file
        (claude-code-tools-send-message-to-claude final-message)
      (message "No file found at point. Are you in a file buffer or magit diff view?"))))

;;;###autoload
(defun claude-code-tools-one-shot ()
  "Execute a non-interactive Claude Code command via the compilation
system.

Prompts for a message and runs the Claude Code CLI in
non-interactive mode via Emacs' `compile` function. The output
appears in a compilation buffer named with the project name. This
is useful for quick queries that don't require an ongoing
conversation."
  (interactive)
  (let ((user-message (read-string "Enter message: "))
        (project-root (file-name-nondirectory (directory-file-name (project-root (project-current))))))
    (let ((default-directory (project-root (project-current))))
      (compile (format "%s %s \"%s\""
                       claude-code-tools-default-claude-command
                       claude-code-tools-oneshot-args
                       user-message))
      (with-current-buffer "*compilation*"
        (rename-buffer (format "*compilation[%s]*" project-root) t)))))

;;;; Internal helper functions

(defun claude-code-tools-send-message-to-claude (message)
  "Send a MESSAGE to the current Claude Code session.

Locates the appropriate Claude Code vterm buffer, displays it,
and sends the message to the running Claude Code session. This is
a helper function used by other commands that build messages."
  (let ((buffer (claude-code-tools-current-claude-code-buffer-name)))
    (display-buffer buffer)
    (with-current-buffer buffer
      (vterm-insert message)
      (vterm-send-return))))

(defun claude-code-tools-current-claude-code-buffer-name ()
  "Get the Claude Code buffer name associated with the current
buffer.

Returns either the buffer-local Claude session name if one has
been set, or derives a default buffer name based on the current
project root. This allows different buffers to be associated with
different Claude sessions."
  (or claude-code-tools-claude-code-buffer-name-local
      (claude-code-tools-claude-code-buffer-name (project-root (project-current)))))

(defun claude-code-tools-claude-code-buffer-name (vc-root-directory)
  "Determine the buffer name for a Claude Code session based on
project root.

VC-ROOT-DIRECTORY is the version control root directory of the
project. Returns a buffer name in the format
'claude-PROJECTNAME'. Checks for a buffer-local variable first,
enabling multiple Claude sessions to be associated with different
buffers within the same project."
  (or claude-code-tools-claude-code-buffer-name-local
      (concat "claude-" (claude-code-tools-vterm-buffer-name-suffix vc-root-directory))))

(defun claude-code-tools-vterm-buffer-name-suffix (directory)
  "Extract a meaningful suffix for the vterm buffer name from a
directory path.

Takes a directory path and returns the name of the directory,
which is used to create unique buffer names for different Claude
Code sessions."
  (file-name-nondirectory
   (directory-file-name (file-name-directory directory))))

(defun claude-code-tools-magit-diff-get-line-number ()
  "Extract line number information from the current diff hunk in
Magit.

Returns a cons cell (line-number . line-count) where:
- line-number is the starting line of the hunk in the target file
- line-count is the number of lines in the hunk

This is used to provide context to Claude when sending from Magit
diffs."
  (save-excursion
    (move-beginning-of-line 1)
    (let ((line-number 0)
          (line-count 0))
      (while (and (not (eobp)) (not (bobp)) (eq line-number 0))
        (when (looking-at "^@@ -[0-9]+,[0-9]+ \\+\\([0-9]+\\),\\([0-9]+\\) @@")
          (setq line-number (string-to-number (match-string 1))
                line-count (string-to-number (match-string 2))))
        (previous-line 1))
      (cons line-number line-count))))

;;;; Transient menu

(transient-define-prefix claude-code-tools-claude-transient ()
  "Claude Code Commands"
  [[ "Commands"
     ("s" "send message" claude-code-tools-send-to-claude)
     ("b" "with buffer" claude-code-tools-send-to-claude-with-buffer)
     ("r" "with region" claude-code-tools-send-to-claude-with-region)
     ("c" "with context" claude-code-tools-send-message-to-claude-with-context)
     ("o" "one-shot" claude-code-tools-one-shot)]
   [ "Session"
     ("O" "open session" claude-code-tools-claude-code-vterm)
     ("S" "select session" claude-code-tools-set-claude-code-buffer-name)
     ("W" "in new worktree" claude-code-tools-open-in-new-worktree)
     ("B" "new prompt buffer" claude-code-tools-create-buffer-for-current-session)]])

(provide 'claude-code-tools)
;;; claude-code-tools.el ends here
