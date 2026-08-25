---
name: explain-codebase
description: Use when explicitly invoked to (1) ensure a codebase is documented and (2) generate an overview of a codebase.
---

# Explain Codebase

Make sure code is documented, and generate an overview of the codebase.

- Iterate through the scope specifed and make sure that each file, class, function has a one-line docstring describing what it does
- Use subagents to fan out across files and directories, a simple model should do (Haiku or Sonnet)
- Respond with an overview of each file, class and function in the specified scope
