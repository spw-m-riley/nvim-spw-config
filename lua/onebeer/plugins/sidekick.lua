---@module "lazy"
---@type LazySpec
local config = require("onebeer.config")

return {
  "folke/sidekick.nvim",
  enabled = function()
    return config.copilot
  end,
  cmd = "Sidekick",
  opts = {
    cli = {
      watch = true, -- auto-reload files changed by Copilot
      mux = {
        enabled = false,
      },
      picker = "fzf-lua",
      win = {
        layout = "right",
        split = {
          width = 100, -- wider for better readability
        },
      },
      -- Copilot-specific prompts
      prompts = {
        -- Code understanding
        explain = [[You are a senior engineer explaining code to a capable teammate. Look at {selection|function|this} in {file} around line {line}.

Explain:
1. **What** this code does — its purpose and responsibility
2. **How** it works — walk through the logic step by step
3. **Why** it's written this way — design decisions, patterns, or tradeoffs
4. Any non-obvious behavior, edge cases, or gotchas to be aware of

Be concise but thorough. Use plain English first; include code examples only if they genuinely add clarity.]],

        explain_error = [[I encountered this error:

{selection}

Please:
1. Explain what this error means in plain English
2. Identify the most likely root cause(s)
3. Provide a concrete fix with corrected code
4. Note any related issues I should watch for while fixing this]],

        -- Code improvement
        fix = [[Fix the following diagnostics in {file}:

{diagnostics}

Requirements:
- Make the **minimal changes** necessary to resolve each diagnostic
- Do not change unrelated code or alter existing behavior
- For each fix, briefly explain what was wrong and why your fix resolves it
- If a diagnostic has multiple valid fixes, prefer the most idiomatic solution for this codebase]],

        refactor = [[Refactor {selection|function|this} to improve code quality.

Focus on:
- **Clarity**: rename variables/functions to better express intent
- **Simplicity**: remove unnecessary complexity or indirection  
- **Maintainability**: apply appropriate patterns or abstractions
- **Consistency**: align with conventions visible in the surrounding code

Constraints:
- Do NOT change external behavior or public APIs
- Do NOT introduce new dependencies unless obviously necessary
- Show the refactored code and briefly explain each meaningful change]],

        optimize = [[Optimize {selection|function|this} for performance.

Please:
1. Identify the specific bottleneck(s) — what's slow and why
2. Provide the optimized code
3. Explain the tradeoff(s) made (e.g., memory vs. speed, readability vs. performance)
4. Estimate the improvement where possible (e.g., O(n²) → O(n log n))

Only optimize what actually matters — don't sacrifice readability for negligible gains.]],

        -- Code generation
        tests = [[Write comprehensive tests for {selection|function|this}.

Cover:
- **Happy path**: expected inputs producing expected outputs
- **Edge cases**: boundary values, empty inputs, large inputs, type coercions
- **Error paths**: invalid inputs, missing data, thrown errors, rejected promises
- **Side effects**: any async behavior, stateful interactions, or external calls

Use the testing framework and patterns already present in this codebase. Each test should have a descriptive name that explains *what* it verifies and *why* it matters. Prefer tests that document behavior over tests that merely achieve coverage.]],

        docs = [[Add documentation comments to {selection|function|this}.

Requirements:
- Use the idiomatic documentation format for this language (JSDoc, LuaDoc, Python docstrings, etc.)
- Document: **purpose**, **parameters** (name, type, description), **return value**, and **thrown errors/exceptions**
- Include a brief usage example for non-trivial functions or complex APIs
- Be precise and concise — do not restate what the code obviously does
- Document the "why" for any non-obvious design decisions or constraints]],

        types = [[Add or improve type annotations for {selection|function|this}.

Requirements:
- Use **precise, narrow types** — avoid `any`, overly broad unions, or unnecessary optionals
- Type all function parameters, return values, and object properties
- If a correct type is non-obvious, add a brief inline comment explaining your reasoning
- Ensure types are correct at all call sites visible in context
- Prefer type aliases or interfaces over inline object types for reused shapes]],

        -- Review
        review = [[Perform a thorough code review of {file}.

Evaluate across these dimensions — report only **real issues** (skip a section if there's nothing meaningful to flag):

**Bugs & Correctness** — logic errors, off-by-one errors, incorrect assumptions, subtle race conditions  
**Security** — injection risks, improper input validation, credential/secret handling, unsafe operations  
**Performance** — unnecessary work, poor algorithmic complexity, memory leaks, blocking calls  
**Maintainability** — unclear naming, missing abstractions, code duplication, tight coupling  
**Error Handling** — unhandled rejections, silent failures, missing edge cases  

Format each issue as:
> **[Critical|High|Medium|Low]** — *location (line or function)*  
> What's wrong and why it matters.  
> **Fix:** how to resolve it.

End with a one-paragraph overall assessment.

---
Existing diagnostics:
{diagnostics_all}]],

        review_selection = [[Review this code for potential issues:

{selection}

Identify:
- Bugs or incorrect logic
- Security vulnerabilities or unsafe patterns
- Performance problems worth addressing
- Missing error handling or unhandled edge cases
- Anything that would surprise or frustrate a future maintainer

For each issue: explain what's wrong, why it's a problem, and how to fix it. Skip style nitpicks — focus only on things that genuinely matter.]],

        -- Quick context
        buffers = "{buffers}",
        file = "{file}",
        quickfix = "{quickfix}",

        -- Git
        commit = [[Generate a conventional commit message for the following staged changes:

{git_diff}

Rules:
- Format: <type>(<scope>): <description>
- Types: feat, fix, docs, style, refactor, test, chore, perf, ci, build
- Subject line must be under 72 characters
- Use imperative mood ("add feature" not "added feature")
- Scope is optional but use it when the change is clearly scoped to one area
- Add a body paragraph if the change needs context that the subject can't convey
- Do NOT include metadata, co-authors, or commentary outside the commit message

Output only the commit message, nothing else.]],
      },
      context = {
        git_diff = function()
          local handle = io.popen("git diff --staged 2>/dev/null")
          if not handle then
            return false
          end
          local result = handle:read("*a")
          handle:close()
          -- Fall back to unstaged diff if nothing is staged
          if result == "" then
            handle = io.popen("git diff 2>/dev/null")
            if not handle then
              return false
            end
            result = handle:read("*a")
            handle:close()
          end
          return result ~= "" and result or false
        end,
      },
    },
  },
  keys = {
    -- Toggle Copilot CLI
    {
      "<leader>aa",
      function()
        require("sidekick.cli").toggle({ name = "copilot", focus = true })
      end,
      desc = "Toggle Copilot",
      mode = { "n", "v" },
    },
    -- Prompt picker
    {
      "<leader>ap",
      function()
        require("sidekick.cli").prompt()
      end,
      desc = "Copilot Prompts",
      mode = { "n", "v" },
    },
    -- Quick actions (visual mode sends selection)
    {
      "<leader>ae",
      function()
        require("sidekick.cli").send({ prompt = "explain" })
      end,
      desc = "Explain code",
      mode = { "n", "v" },
    },
    {
      "<leader>af",
      function()
        require("sidekick.cli").send({ prompt = "fix" })
      end,
      desc = "Fix diagnostics",
      mode = { "n", "v" },
    },
    {
      "<leader>at",
      function()
        require("sidekick.cli").send({ prompt = "tests" })
      end,
      desc = "Write tests",
      mode = { "n", "v" },
    },
    {
      "<leader>ar",
      function()
        require("sidekick.cli").send({ prompt = "review" })
      end,
      desc = "Review file",
      mode = { "n", "v" },
    },
    {
      "<leader>ao",
      function()
        require("sidekick.cli").send({ prompt = "refactor" })
      end,
      desc = "Refactor code",
      mode = { "n", "v" },
    },
    {
      "<leader>ac",
      function()
        require("sidekick.cli").send({ prompt = "commit" })
      end,
      desc = "Generate commit message",
      mode = { "n" },
    },
  },
}
