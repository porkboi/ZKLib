-- import Mathlib.Data.Fintype.Basic
import Jolt.Data.ComputableDistribution

/-!
# Formalism of Interactive Oracle Proofs

We define (public-coin) interactive oracle proofs (IOPs). This is an interactive protocol between a prover and a verifier with the following format:

  - At the beginning, the prover and verifier both hold a public statement x (and potentially have access to some public parameters pp). The prover may also hold some private state which in particular may contain a witness w to the statement x.

  - In each round, the verifier sends some random challenges, and the prover sends back responses to the challenges. The responses are received as oracles by the verifier. The verifier only sees some abstract representation of the responses, and is only allowed to query these oracles in specific ways (i.e. point queries, polynomial evaluation queries, tensor queries).

  - At each step, the verifier may make oracle queries and perform some checks on the responses so far. At the end of the interaction, the verifier outputs a bit indicating accept or reject; it may also output the bit earlier at any round.

Note: the definition of IOPs as defined above generalizes those found in the literature. It has the same name as the interactive protocol in the [BCS16] paper, but it is strictly more general. We call the IOP defined in [BCS16] as a "point IOP". We also get "polynomial IOP" [BCG+19] and "tensor IOP" [BCG20] (and other kinds of IOPs) from our definition.

We formalize IOPs with the following objects:

  - The prover and verifier are modeled as Monads (especially if they are probabilistic). In particular, we define the "proverM" and "verifierM" monads.

  - The "proverM" monad has the following structure:

-/



-- Type signature for a single round of the prover
-- Takes in an instance, a prover state, a list of challenges for the current round, and a randomness value, then outputs a response and a new prover state
def proverRound (Instance ProverState Challenge Randomness Response : Type) :=
  Instance → ProverState → List Challenge → Randomness → (Response × ProverState)

opaque def maliciousProver :=

-- Define the structure for the interactive proof system
-- Note: this structure is bad / not general enough, since it assumes the verifier takes the same action in each round (i.e. for ver1)
structure InteractiveOracleProof (ProverType : Type _) (VerifierType : Type _) where
  honestProver : ProverType
  honestVerifier : VerifierType

  -- (ver0 : Instance → VerifierState → Bool)
  -- (ver1 : Instance → Response → Randomness → Challenge → List Challenge → VerifierState → (Bool × Instance × VerifierState))

-- Define the prove function within the context of InteractiveProof
namespace InteractiveProof

-- variables {Instance VerifierState Response Randomness Challenge ProverState : Type}

def execution (ip : InteractiveProof Instance VerifierState Response Randomness Challenge)
          (vs : VerifierState) (prv : proverRound Instance ProverState Challenge Randomness Response)
          (ps : ProverState) (inst : Instance) (rnd : Randomness) (rounds : List (Challenge × Randomness)) : Bool :=
  match rounds with
  | [] => ip.ver0 inst vs
  | (round_data, rnd') :: remaining_rounds =>
    let (resp, ps') := prv inst round_data (remaining_rounds.map Prod.fst) rnd ps in
    let (ok, inst', vs') := ip.ver1 inst resp rnd' round_data (remaining_rounds.map Prod.fst) vs in
    ok && prove ip vs' prv ps' inst' rnd' remaining_rounds

end InteractiveProof

-/


namespace PolynomialIop

variable {F : Type} [Field F] [Fintype F]
variable {Stmt : Type} {Wit : Type} {Randomness : Type}

-- upgrade this to multivariate polynomials (w/o explicit bound on number of variables)
def ProverMessage := List (Polynomial F)

def ChallengeRound : Type := List F

def QueryPoints : Type := List (List F)

def Evaluations : Type := List (List F)

-- We let witness be both the witness to the protocol, but also mutable during prover's execution as prover's state
def ProverRound {Stmt Wit Randomness : Type} : Type := Stmt → Wit → @ChallengeRound F → Randomness → (@ProverMessage F × Wit)

def Prover {Stmt Wit Randomness : Type} : Type := List (@ProverRound Stmt Wit (@ChallengeRound F) Randomness)

def QuerySampler : Type := Stmt → List (@ChallengeRound F) → @QueryPoints F

def Verification :  Type := Stmt → QueryPoints → Evaluations → Bool

def Verifier : Type := QuerySampler × Verification


structure PolyIop (F : Type) [Field F] [Fintype F] (Stmt : Type) (Wit : Type) where
  -- number of rounds, may depend on statement
  numRounds : Stmt → ℕ

  -- number of polynomials in each round
  numPolys : Stmt → ℕ → ℕ

  -- number of variables in each polynomial
  numVars : Stmt → ℕ → ℕ → ℕ

  -- maximum number of variables for any polynomial
  maxNumVars : Stmt → ℕ

  -- degree bounds for each polynomial
  degreeBounds : Stmt → ℕ → ℕ → Finset ℕ

  -- number of challenges in each round
  -- (each challenge is a field element)
  numChals : Stmt → ℕ → ℕ

  honestProver : Prover

  honestVerifier : Verifier


/-
  -- Define the prover function
  prover : Stmt → Wit → ℕ → List F → (List (Polynomial F), List F)
  prover stmt wit 0 randomness :=
    let polys := List.range (numPolys stmt 0) |>.map (λ _, generatePolynomial (numVars stmt 0 _) (degreeBound stmt 0 _))
    let newState := updateState stmt wit randomness
    (polys, newState)
  prover stmt wit (i + 1) randomness :=
    let (prevPolys, prevState) := prover stmt wit i randomness
    let newRandomness := proverRandomness stmt (i + 1)
    let polys := List.range (numPolys stmt (i + 1)) |>.map (λ _, generatePolynomial (numVars stmt (i + 1) _) (degreeBound stmt (i + 1) _))
    let newState := updateStateBasedOnPrevState stmt wit prevState newRandomness
    (polys, newState)


  roundRandomness : Stmt → ComputableDistribution (Coins F)

  oracleQueries : Stmt → (Coins F) → List (List F)

  verification : Stmt → (Coins F) → (ℕ → List (F × F)) → Bool
-/


-- Perfect completeness here
def PolyIop.complete (F : Type) [Field F] [Fintype F] {Stmt Wit : Type}
    (Relation : Stmt → Wit → Prop)
    (𝓟 : PolyIop F Stmt Wit) : Prop :=  -- For any statement and witness that satisfy the relation ...
  ∀ stmt : Stmt, ∀ wit : Wit, Relation stmt wit →
  -- The proof should verify with probability 1
    (do -- This do block over the probability monad is interpreted as a function
      let coins ← 𝓟.roundRandomness stmt
      let oracles : ℕ → Polynomial F := fun i =>
        𝓟.prover stmt wit (coins.take i)
      let oracle_queries : ℕ → List F := fun i => (𝓟.oracleQueries stmt coins).getD i []
      let oracle_responses : ℕ → List F := fun i =>
        (oracles i).eval <$> (oracle_queries i)
      let query_response_pairs : ℕ → List (F × F) := fun i =>
        List.zip (oracle_queries i) (oracle_responses i)
      let verified := (𝓟.verification stmt coins query_response_pairs)
      return verified
    ).toFun true = 1


-- Todo: allow promises of statements
def PolyIop.sound (F : Type) [Field F] [Fintype F] {Stmt Wit : Type}
    (Relation : Stmt → Wit → Prop)
    (𝓟 : PolyIop F Stmt Wit)
    (extractor : Stmt → @ProofProducer F → Wit)
    (soundnessBound : Rat) : Prop :=
-- For any statement and any adversary ...
  ∀ stmt : Stmt, ∀ adv_prover : @ProofProducer F,
  -- ... if the probability of convinicing the verifier is more than the soundness ε ...
  (do
    let coins ← 𝓟.roundRandomness stmt
    let oracles : ℕ → Polynomial F := fun i =>
      adv_prover (coins.take i)
    let oracle_queries : ℕ → List F := fun i => (𝓟.oracleQueries stmt coins).getD i []
    let oracle_responses : ℕ → List F := fun i =>
      (oracles i).eval <$> (oracle_queries i)
    let query_response_pairs : ℕ → List (F × F) := fun i =>
      List.zip (oracle_queries i) (oracle_responses i)
    let verified := (𝓟.verification stmt coins query_response_pairs)
    return verified
      ).toFun true > soundnessBound
      -- ... then the extractor gives a valid witness.
      → Relation stmt (extractor stmt adv_prover)

-- A notion of soundness enriched with a return value (should I build it into the statement?)
def PolyIop.sound_enriched (F : Type) [Field F] [Fintype F] {Stmt Wit A : Type}
    (Relation : Stmt → Wit -> A → Prop)
    (𝓟 : PolyIop F Stmt Wit)
    (extractor :-- Should the extractor have access to stmt? Does it matter?
        Stmt →
        @ProofProducer F → Wit)
    (soundnessBound : Rat) : Prop :=
-- For any statement and any adversary ...
  ∀ stmt : Stmt, ∀ adv_prover : @ProofProducer F, ∀ a : A,
  (do
    let coins ← 𝓟.roundRandomness stmt
    let oracles : ℕ → Polynomial F := fun i =>
      adv_prover (coins.take i)
    let oracle_queries : ℕ → List F := fun i => (𝓟.oracleQueries stmt coins).getD i []
    let oracle_responses : ℕ → List F := fun i =>
      (oracles i).eval <$> (oracle_queries i)
    let query_response_pairs : ℕ → List (F × F) := fun i =>
      List.zip (oracle_queries i) (oracle_responses i)
    let verified := (𝓟.verification stmt coins query_response_pairs)
    return verified ∨ ¬ Relation stmt (extractor stmt adv_prover) a
      ).toFun true > soundnessBound

end PolynomialIop
