# Plan 005: Make Mule catalog generation non-empty or honest

> **Executor instructions**: Follow this plan step by step. Run every verification command and confirm the expected result before moving to the next step. If anything in the "STOP conditions" section occurs, stop and report; do not improvise. When done, update the status row for this plan in `plans/README.md` unless your dispatcher owns the index.
>
> **Drift check (run first)**: `git diff --stat 5d80f88..HEAD -- lua/onebeer/mule/catalog.lua lua/onebeer/mule/commands.lua lua/onebeer/mule/smoke.lua doc/onebeer.txt docs/mule-workflow.html plans/README.md`
> If any in-scope file changed since this plan was written, compare the "Current state" excerpts below against live code before proceeding; on a mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: none
- **Category**: bug / dx
- **Planned at**: commit `5d80f88`, 2026-07-10

## Why this matters

The current `:MuleGenerateCatalog` command always reports success in a Mule project, but it passes an empty mapping list to the catalog writer. That creates a valid XML catalog file with no useful `<uri>` entries, so LemMinX appears configured while resolving no Mule schemas. The command should either generate at least one local mapping or refuse with an actionable message.

## Current state

- `lua/onebeer/mule/catalog.lua` writes whatever mappings it receives, including an empty list:

```lua
-- lua/onebeer/mule/catalog.lua:28-40
local lines = {
  '<?xml version="1.0" encoding="UTF-8"?>',
  '<catalog xmlns="urn:oasis:names:tc:entity:xmlns:xml:catalog">',
}
for _, mapping in ipairs(mappings) do
  lines[#lines + 1] = ('  <uri name="%s" uri="%s" />'):format(
    xml_escape(mapping.uri),
    xml_escape(vim.fs.normalize(mapping.path))
  )
end
lines[#lines + 1] = "</catalog>"
```

- `lua/onebeer/mule/commands.lua` calls the generator with no mappings:

```lua
-- lua/onebeer/mule/commands.lua:160-175
local function generate_catalog()
  ...
  local output, err = catalog.generate(vim.api.nvim_buf_get_name(0), {})
  if output == nil then
    vim.notify(err or "Failed to generate Mule XML catalog", vim.log.levels.ERROR, { title = title })
    return
  end

  vim.notify(("Mule XML catalog written to %s"):format(output), vim.log.levels.INFO, { title = title })
end
```

- `doc/onebeer.txt:620` and `docs/mule-workflow.html:293` describe `:MuleGenerateCatalog` as useful for LemMinX.
- `lua/onebeer/mule/smoke.lua:346-367` proves explicit mappings work, but does not prove the command can discover any mapping.

## Commands you will need

| Purpose | Command | Expected on success |
| --- | --- | --- |
| Catalog smoke | `nvim --headless "+lua require('onebeer.mule.smoke').run('lemminx-catalog')" +qa` | exit 0 |
| Lua lint | `selene .` | exit 0 |
| Format check | `stylua --check .` | exit 0 |
| Help tags | `nvim --headless "+helptags doc" +qa` | exit 0 |

## Scope

**In scope**:
- `lua/onebeer/mule/catalog.lua`
- `lua/onebeer/mule/commands.lua`
- `lua/onebeer/mule/smoke.lua`
- `lua/onebeer/mule/fixtures/**` only if a local XSD fixture is missing
- `doc/onebeer.txt`
- `docs/mule-workflow.html`
- `plans/README.md`

**Out of scope**:
- Maven artifact download/extraction.
- Any remote schema fetch.
- Credential handling for private Mule repositories.
- Broader LemMinX startup or LSP configuration changes.

## Git workflow

- Branch suggestion: `advisor/005-mule-catalog-generation`.
- Commit message style: conventional commit, for example `fix: make mule catalog generation honest`.
- Do not push or open a PR unless explicitly instructed.

## Steps

### Step 1: Add local XSD mapping discovery

In `lua/onebeer/mule/catalog.lua`, add a function that discovers local schema mappings from a detected Mule project:

- Scan at least these roots when they exist:
  - `project.root .. "/src/main/resources/**/*.xsd"`
  - `project.root .. "/exchange_modules/**/*.xsd"`
- For each XSD file, read enough text to find `targetNamespace="..."` or `targetNamespace='...'`.
- Return a sorted `onebeer.mule.CatalogMapping[]` where `uri` is the target namespace and `path` is the XSD path.
- Skip XSD files without a `targetNamespace` rather than guessing.
- Deduplicate by namespace, preferring the first sorted path, and keep the output deterministic.

Keep `catalog.generate(startpath, mappings, output)` usable for explicit mappings. Add a small helper such as `catalog.discover(project)` rather than folding discovery directly into the command callback.

**Verify**: `nvim --headless "+lua require('onebeer.mule.smoke').run('lemminx-catalog')" +qa` -> exit 0.

### Step 2: Refuse empty generated catalogs

Change `catalog.generate` or the command callback so `:MuleGenerateCatalog` does not write an empty catalog. Recommended shape:

- `catalog.generate(startpath, nil, output)` discovers mappings from the project.
- `catalog.generate(startpath, {}, output)` remains the explicit-mapping path used by tests if needed, but returns `nil, "No Mule XML schema mappings found"` unless a caller opts into empty output.
- `generate_catalog()` calls discovery, and warns if no local XSD mappings exist.

The key invariant: the user command must not create `.onebeer/mule-catalog.xml` with zero `<uri>` entries.

**Verify**: Add or update smoke assertions in the `lemminx-catalog` stage so it proves both:

- A fixture project with a local XSD produces a catalog containing at least one `<uri ... />`.
- An empty/no-XSD fixture returns a clear no-mappings error and does not write an empty catalog.

Then run `nvim --headless "+lua require('onebeer.mule.smoke').run('lemminx-catalog')" +qa` -> exit 0.

### Step 3: Align docs with the honest behavior

Update `doc/onebeer.txt` and `docs/mule-workflow.html` so they say:

- `:MuleGenerateCatalog` maps local XSDs discovered under project resources or Exchange module directories.
- If no local schemas are found, the command reports that rather than pretending LemMinX is configured.
- Maven artifact extraction and remote/private schema fetching remain out of scope for this command.

Do not add screenshots or VHS assets for this.

**Verify**: `nvim --headless "+helptags doc" +qa` -> exit 0.

## Test plan

- Extend `lua/onebeer/mule/smoke.lua` `lemminx-catalog` coverage.
- Use existing fixture project structure under `lua/onebeer/mule/fixtures/projects/basic-mule`.
- Add the smallest XSD fixture needed if no usable local XSD exists.

## Done criteria

- [ ] `:MuleGenerateCatalog` cannot write a zero-mapping catalog while reporting success.
- [ ] Local XSD target namespaces produce deterministic catalog mappings.
- [ ] Empty projects produce an actionable no-mappings message.
- [ ] `nvim --headless "+lua require('onebeer.mule.smoke').run('lemminx-catalog')" +qa` exits 0.
- [ ] `stylua --check .` exits 0.
- [ ] `selene .` exits 0.
- [ ] `nvim --headless "+helptags doc" +qa` exits 0.
- [ ] `plans/README.md` status row updated.

## STOP conditions

Stop and report if:

- Local fixture projects do not contain, and cannot safely add, a representative XSD fixture.
- A correct implementation appears to require downloading Maven artifacts or contacting MuleSoft services.
- LemMinX settings must be changed to complete this plan.
- Any verification fails twice after a reasonable fix attempt.

## Maintenance notes

This plan deliberately does not implement Maven artifact XSD extraction. If that becomes necessary, do it as a separate plan with explicit credential and offline-cache behavior.
