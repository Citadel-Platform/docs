# Feature 5.2 - Baker MVP Bootstrap

## Status
**Built 05/09/26**, with one deliberate boundary: Factory runs from a
terminal, on a machine with a checkout and a toolchain — the client's
Devstation, or the operator's own laptop — and not from the Console. A
bootstrap installs dependencies, runs a build and launches an application, and
the Platform API has no workspace to do that in and no business holding one.

So Task 5.2.3's validation is the operator's `flutter analyze` and `flutter
test`, run where the code is, and the Console's part is to say exactly what to
run and what a codebase was built from. The commands are written out rather
than hidden behind a button: a Console that pretended to run them would be
claiming credit for a build it never saw.

## Scope
Apply Factory kits, recipes and the context pack to create the initial working
MVP quickly. This phase ends at a runnable first application and a recorded
version trail; it does not own long-term upgrades, manifests or broad
autonomous mutation.

## Tasks

### Task 5.2.1 - Bootstrap flow
- Select a supported starting stack and a small set of feature recipes.
- Show exactly which asset versions will be used before writing source.
- Create a new repository/workspace or target an explicitly selected empty
  starter repository.

### Task 5.2.2 - Source generation
- Materialise the selected component kits and recipe wiring into the codebase.
- Write the basic used-version record alongside the source.
- Never overwrite unrelated source without explicit, visible confirmation.

### Task 5.2.3 - Validation
- Install dependencies, run static analysis/tests and launch the MVP.
- Surface every failure and remediation step in the Console.
- Verify Firebase configuration and Citadel SDK integration from live/emulated
  sources; never populate fake business data.

### Task 5.2.4 - Devstation handoff
- Surface the per-client Devstation provisioning and lifecycle steps in the
  Console so the operator can hand off into the development VM when needed.
- Keep the flow Terraform-backed and visibly guided, not a hidden script or
  checklist.

## Definition of done
- [x] A supported project bootstraps from zero to a runnable MVP, guided by
      the Console and run where the code is (05/09/26). The Bootstrap tab
      names the recipes, what each is made of, the version the catalogue holds
      for every module today, and the exact commands — with the client's own
      Devstation SSH command filled in when they have one.
- [x] Generated source records the exact Factory asset versions used
      (05/09/26) — `baker.lock.json`, with commits and content digests.
- [x] Static analysis and functional tests pass on the generated application
      (05/09/26), as a test in the Factory package rather than by hand.
- [x] Devstation provisioning and external actions remain visible in the
      Console (05/09/26). See Feature 5.3.
- [ ] A browser smoke test of the *generated* application. Its widget tests
      run; nothing drives it in a browser.
