import Lake
open Lake DSL

/- Options for ZKLib that are taken from mathlib -/

/-- These options are used
* as `leanOptions`, prefixed by `` `weak``, so that `lake build` uses them;
* as `moreServerArgs`, to set their default value in zklib
  (as well as `Archive`, `Counterexamples` and `test`).
-/
abbrev zklibOnlyLinters : Array LeanOption := #[
  ⟨`linter.docPrime, true⟩,
  ⟨`linter.hashCommand, true⟩,
  ⟨`linter.oldObtain, true,⟩,
  ⟨`linter.refine, true⟩,
  ⟨`linter.style.cdot, true⟩,
  ⟨`linter.style.dollarSyntax, true⟩,
  ⟨`linter.style.lambdaSyntax, true⟩,
  ⟨`linter.style.longLine, true⟩,
  ⟨`linter.style.longFile, .ofNat 1500⟩,
  ⟨`linter.style.missingEnd, true⟩,
  ⟨`linter.style.setOption, true⟩
]

/-- These options are passed as `leanOptions` to building zklib, as well as the
`Archive` and `Counterexamples`. (`tests` omits the first two options.) -/
abbrev zklibLeanOptions := #[
    ⟨`pp.unicode.fun, true⟩, -- pretty-prints `fun a ↦ b`
    ⟨`autoImplicit, false⟩
  ] ++ -- options that are used in `lake build`
    zklibOnlyLinters.map fun s ↦ { s with name := `weak ++ s.name }

def moreServerArgs := #[
  "-Dpp.unicode.fun=true", -- pretty-prints `fun a ↦ b`
  "-DAutoImplicit=false"
]

package «Zklib» {
  -- add any package configuration options here
  leanOptions := zklibLeanOptions
  -- Mathlib also enforces these linter options, which are not active by default.
  moreServerOptions := zklibOnlyLinters
}


require mathlib from git
  "https://github.com/leanprover-community/mathlib4.git" @ "master"
-- require LeanCopilot from git "https://github.com/lean-dojo/LeanCopilot.git" @ "v1.0.0"

require VCVio from git
  "https://github.com/dtumad/VCV-io.git" @ "master"

@[default_target]
lean_lib «ZKLib» {
  -- add any library configuration options here
}

require checkdecls from git "https://github.com/PatrickMassot/checkdecls.git"

-- meta if get_config? env = some "dev" then
require «doc-gen4» from git
  "https://github.com/leanprover/doc-gen4" @ "main"
