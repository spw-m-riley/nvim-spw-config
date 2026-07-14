# Plan 004: Tighten the APIKit navigation contract

> **Executor instructions**: Follow this plan step by step. Run every verification command and confirm the expected result before moving to the next step. If anything in the "STOP conditions" section occurs, stop and report - do not improvise. When done, update the status row for this plan in `plans/README.md` unless a reviewer tells you they maintain the index.
>
> **Drift check (run first)**: `git diff --stat 5d80f88..HEAD -- lua/onebeer/mule/api/apikit.lua lua/onebeer/mule/api/spec_paths.lua lua/onebeer/mule/index.lua lua/onebeer/mule/smoke.lua lua/onebeer/mule/fixtures/projects/basic-mule doc/onebeer.txt docs/mule-workflow.html`
> If any in-scope file changed since this plan was written, compare the "Current state" excerpts against the live code before proceeding; on a mismatch, treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: MED - navigation behavior touches parser assumptions and user-facing docs.
- **Depends on**: none
- **Category**: direction
- **Planned at**: commit `5d80f88`, 2026-07-10, against the current uncommitted Mule workflow draft.

## Why this matters

APIKit navigation is a high-value replacement for Studio-style clicking around generated flows, but the current contract is narrower than the docs imply. The resolver finds a local spec file and searches for a flat RAML route line. It does not prove nested RAML resources, OAS paths, or Exchange include resolution work. Users need either stronger navigation or more truthful docs so they know when the feature applies.

## Current state

- `lua/onebeer/mule/api/apikit.lua` only finds a single route line matching the complete path:

```lua
57. local function find_route_line(spec_path, route)
...
64.   for line_number, line in ipairs(lines) do
65.     if line:match("^%s*" .. vim.pesc(route.path) .. ":%s*$") then
66.       route_line = line_number
67.     elseif route_line and line:match("^%s+" .. route.method .. ":%s*$") then
68.       return line_number
69.     elseif route_line and line:match("^/") then
70.       route_line = nil
```

- `lua/onebeer/mule/api/spec_paths.lua` only resolves direct local resource paths and lists Exchange module files:

```lua
7. function M.resolve_api(project, api)
8.   if api:match("^resource::") then
9.     return nil
10.   end
...
21. function M.exchange_modules(project)
```

- `docs/mule-workflow.html` describes broader behavior:

```html
340. The APIKit parser understands generated flow names such as <code>get:\health:api-config</code> and maps them
341. back to local RAML/OAS paths declared by <code>apikit:config</code>. Exchange module paths under
342. <code>src/main/resources/api/exchange_modules/</code> are indexed for include resolution.
```

- `doc/onebeer.txt` describes the workflow but does not state the flat-route limitation.

## Commands you will need

| Purpose | Command | Expected on success |
| --- | --- | --- |
| Format check | `stylua --check .` | exit 0 |
| Lint | `selene .` | exit 0 |
| APIKit smoke | `nvim --headless "+lua require('onebeer.mule.smoke').run('apikit-navigation')" +qa` | exit 0 |
| Help tags if `doc/onebeer.txt` changes | `nvim --headless "+helptags doc" +qa` | exit 0 |

## Scope

**In scope**
- `lua/onebeer/mule/api/apikit.lua`
- `lua/onebeer/mule/api/spec_paths.lua`
- `lua/onebeer/mule/smoke.lua`
- `lua/onebeer/mule/fixtures/projects/basic-mule/src/main/resources/api/**`
- `doc/onebeer.txt`
- `doc/tags` if help tags are regenerated
- `docs/mule-workflow.html`

**Out of scope**
- Full RAML/OAS validation
- Network calls to Exchange or Anypoint
- Bundling closed MuleSoft tooling

## Git workflow

- Branch: `advisor/004-tighten-apikit-navigation-contract`
- Commit message style: conventional commits, for example `fix: tighten mule apikit navigation`
- Do not push or open a PR unless explicitly instructed.

## Steps

### Step 1: Choose and document the contract

Pick one of these approaches before editing code:

1. **Narrow contract**: explicitly support local RAML files with flat top-level routes only. Remove OAS and Exchange-include wording from docs.
2. **Expanded contract**: support local RAML nested resources and OAS `paths`, while keeping Exchange network resolution out of scope.

Prefer the expanded contract if it can be implemented with small deterministic parsers and fixtures. If not, use the narrow contract and make the docs truthful.

**Verify**: write a short note in the commit message body or plan status update naming which contract was chosen.

### Step 2: Add fixture coverage for the chosen contract

For the expanded contract, add fixture routes that prove:

- nested RAML path segments map to the generated APIKit flow path
- OAS `paths` entries map to method lines or path lines
- unresolved `resource::` or Exchange-only specs fail with a clear message

For the narrow contract, add a smoke assertion that an unsupported nested/OAS route returns a clear limitation message rather than silently implying support.

**Verify**: `nvim --headless "+lua require('onebeer.mule.smoke').run('apikit-navigation')" +qa` -> expected to fail until Step 3 implements behavior/docs.

### Step 3: Implement or constrain route resolution

Update `lua/onebeer/mule/api/apikit.lua` and `spec_paths.lua` to match the selected contract.

Expanded-contract guidance:

- Keep parsing line-oriented and deterministic; do not add new dependencies.
- Return the most useful line: method line if found, otherwise path line.
- Keep `resource::` remote specs unsupported unless a local file can be resolved without network access.

Narrow-contract guidance:

- Return a clear error string for unsupported spec shapes.
- Avoid returning a target table with a `nil` line when route lookup failed.

**Verify**: `nvim --headless "+lua require('onebeer.mule.smoke').run('apikit-navigation')" +qa` -> exit 0.

### Step 4: Align docs and help tags

Update `doc/onebeer.txt` and `docs/mule-workflow.html` so the APIKit section matches the implemented contract exactly.

If `doc/onebeer.txt` changes, regenerate help tags:

`nvim --headless "+helptags doc" +qa`

**Verify**: `rg -n "RAML/OAS|Exchange module|APIKit" doc/onebeer.txt docs/mule-workflow.html` -> wording matches the chosen contract and does not overclaim unsupported behavior.

## Test plan

- Keep all APIKit verification in the `apikit-navigation` smoke stage.
- Add fixture files rather than depending on a real Mule project.
- Run `stylua --check .`, `selene .`, and help tags if Vim help changes.

## Done criteria

- [ ] APIKit navigation either supports the documented route shapes or reports unsupported shapes clearly.
- [ ] Docs no longer imply OAS or Exchange include behavior unless smoke tests prove it.
- [ ] `nvim --headless "+lua require('onebeer.mule.smoke').run('apikit-navigation')" +qa` exits 0.
- [ ] `stylua --check .` exits 0.
- [ ] `selene .` exits 0.
- [ ] `nvim --headless "+helptags doc" +qa` exits 0 if `doc/onebeer.txt` changed.
- [ ] No files outside the in-scope list are modified, except `plans/README.md` status if this plan is executed directly.

## STOP conditions

Stop and report if:

- Implementing the expanded contract requires a real RAML/OAS parser dependency.
- Exchange resolution would require network calls or credentials.
- The docs and implementation cannot be made consistent without removing a user-visible promise from the original Mule plan.

## Maintenance notes

Reviewers should reject any implementation that silently returns `{ spec_path = ..., line = nil }` for a route that could not be located. A missing route should be explicit so navigation failures are debuggable.
