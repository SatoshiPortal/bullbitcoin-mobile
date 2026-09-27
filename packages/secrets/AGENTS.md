# Public API documentation

When changing the public API, regenerate the simplified `Secrets` and `Secret` call trees with `make secrets-api-docs` from the repository root. Include the generated README update with the API change and update the surrounding prose when behavior changes. Do not hand-edit the generated block or maintain a separate list of operations.

`make secrets-api-docs-check` compares the resolved public export namespace with the versioned trees without writing files. It runs in `make checks` and CI. The generator follows exported extension members and synchronous capability groups, excludes internal members, and simplifies asynchronous Result returns; `doc/design.md` documents its scope.
