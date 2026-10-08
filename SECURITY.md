# Security policy

## Reporting a vulnerability

Please report security problems privately, not in a public issue.

1. **GitHub (preferred):** open the [Security tab](https://github.com/flaris-lang/flaris/security)
   of this repository and choose **Report a vulnerability**.
2. **Email:** flaris-lang@solidinvention.se, with a subject line starting `[SECURITY]`.

A useful report includes:

- the version (`flarisvm --version`) and platform;
- the smallest `.fls` script or `.flx` file that shows the problem;
- what an attacker gains, as you understand it.

## What happens next

- We acknowledge your report within **7 days**.
- Within **30 days** we tell you whether we accept it, how severe we rate it,
  and when we expect a fix.
- The fix ships in the next release, and the changelog credits you unless you
  ask us not to.

## Disclosure

We follow coordinated disclosure. Please keep the details private until a fix
has been released or **90 days** have passed since your report, whichever comes
first. If a fix needs longer, we will ask you, and explain why.

## Supported versions

Only the **latest release** receives security fixes. Fixes are not backported;
upgrade to the release that contains the fix.

## Scope

This policy covers the Flaris VM and tools (`flarisvm`, the runtime-only
`flaris`, `libflaris` including its WebAssembly module, and `flarispm`), the
libraries in this repository, and the VS Code extension.

In scope, for example:

- memory-safety bugs in the VM reachable from a script or a `.flx` file;
- a script or context reaching more than it was granted: a built-in module
  denied to it, or a capability it does not hold;
- loading code that should have been refused: a bad signature accepted, a
  `--require-signed` check bypassed, or a `flarispm` integrity pin not enforced;
- a library in this repository mishandling untrusted input, such as a parser
  crashing the VM or a TLS or HTTP library accepting what it must refuse.

Not vulnerabilities, because they are documented behaviour:

- what a script does with `--unsafe`, `Ffi` or raw `Memory` access, which
  trusts the script completely;
- memory held by a reference cycle (see *Reference cycles are never collected*
  in the language reference);
- a script with no instruction or memory limits configured running for a long
  time or using all the memory it was allowed.

## Verifying releases

Official libraries and releases are signed with Ed25519, by the signer the tools
show as `flaris-lang.org`. Its public key is:

    d43ec4260fe82ee101a939caabff95358b0698718d7b8c38652b5457bdf59621

It is also published at https://www.flaris-lang.org/#signing. Run with
`--require-signed` to refuse any bytecode not signed by a key you trust.
