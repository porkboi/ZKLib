/-
Copyright (c) 2024 ZKLib Contributors. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Quang Dao
-/

import Mathlib.Algebra.Tropical.Basic
import Mathlib.RingTheory.Polynomial.Basic
import ZKLib.Data.Math.Operations

/-!
  # Univariate Polynomials with Efficient Operations

  This file is based on various similar implementations. Credits:
  - Bolton Bailey
  - ...
-/

namespace Array

def trim {R : Type*} [DecidableEq R] (a : Array R) (y : R) : Array R :=
  a.popWhile (fun x => x = y)

theorem trim_trim {R : Type*} [DecidableEq R] (a : Array R) (y : R) :
    (a.trim y).trim y = a.trim y := by
  simp [trim]
  sorry

end Array

open Polynomial

/-- A type analogous to `Polynomial` that supports computable operations. This polynomial is
  represented internally as an Array of coefficients.

For example the Array `#[1,2,3]` represents the polynomial `1 + 2x + 3x^2`. Two arrays may represent
the same polynomial via zero-padding, for example `#[1,2,3] = #[1,2,3,0,0,0,...]`.
 -/
@[ext, specialize]
structure UniPoly (R : Type*) [Semiring R] where
  mk::
  coeffs : Array R
deriving Inhabited, DecidableEq, Repr

@[ext, specialize]
structure UniPoly' (R : Type*) [Semiring R] [DecidableEq R] where
  coeffs : Array R
  hTrim : coeffs.trim 0 = coeffs
  -- Alternatively (requires `Nontrivial R` as well)
  -- hTrim' : coeffs.getLastD 1 ≠ 0
deriving Repr

namespace UniPoly

variable {R : Type*} [Semiring R] [BEq R]
variable {Q : Type*} [Semiring Q]

instance [DecidableEq R] : Inhabited (UniPoly' R) := ⟨⟨#[], rfl⟩⟩

/-- Another way to access `coeffs` -/
def toArray (p : UniPoly R) : Array R := p.coeffs

/-- The size of the underlying array. This may not correspond to the degree of the corresponding
  polynomial if the array has leading zeroes. -/
@[reducible]
def size (p : UniPoly R) : Nat := p.coeffs.size

/-- The constant polynomial `C r`. -/
def C (r : R) : UniPoly R := ⟨#[r]⟩

/-- The variable `X`. -/
def X : UniPoly R := ⟨#[0, 1]⟩

/-- Return the index of the last non-zero coefficient of a `UniPoly` -/
def last_non_zero [BEq R] (p: UniPoly R) : Option (Fin p.size) :=
  p.coeffs.findIdxRev? (· != 0)

/-- Remove leading zeroes from a `UniPoly`. Requires `BEq` to check if the coefficients are zero. -/
def trim [BEq R] (p : UniPoly R) : UniPoly R :=
  match p.last_non_zero with
  | none => ⟨#[]⟩
  | some i => ⟨p.coeffs.extract 0 (i.val + 1)⟩

/-- Return the degree of a `UniPoly`. -/
def degree [BEq R] (p : UniPoly R) : Nat :=
  match p.last_non_zero with
  | none => 0
  | some i => i.val + 1

/-- Return the leading coefficient of a `UniPoly` as the last coefficient of the trimmed array,
or `0` if the trimmed array is empty. -/
def leadingCoeff [BEq R] (p : UniPoly R) : R := p.trim.coeffs.getLastD 0

namespace Trim

-- characterize .last_non_zero
theorem last_non_zero_none [LawfulBEq R] {p : UniPoly R} :
  (∀ i, (hi : i < p.size) → p.coeffs[i] = 0) → p.last_non_zero = none
:= by
  intro h
  apply Array.findIdxRev?_eq_none
  intro a ha
  suffices a = 0 by rwa [bne_iff_ne, ne_eq, not_not]
  -- translate index access to array membership
  -- TODO if this is nicer to use then we should use index access in `Array.findIdxRev?` theorems
  obtain ⟨ i, hi, rfl: p.coeffs[i] = a ⟩ := Array.mem_iff_getElem.mp ha
  exact h i hi

theorem last_non_zero_some [LawfulBEq R] {p : UniPoly R} {i} (hi: i < p.size) (h: p.coeffs[i] ≠ 0) :
  ∃ k, p.last_non_zero = some k
:= Array.findIdxRev?_eq_some ⟨p.coeffs[i], Array.getElem_mem _, bne_iff_ne.mpr h⟩

-- theorem to pass to `cases` when reasoning about last_non_zero and trim
theorem last_none_zero_cases [LawfulBEq R] (p : UniPoly R) :
  (p.last_non_zero = none ∧ (∀ i, (hi : i < p.size) → p.coeffs[i] = 0))
  ∨ (∃ k, p.last_non_zero = some k)
:= by
  by_cases h : ∀ i, (hi : i < p.size) → p.coeffs[i] = 0
  · left; exact ⟨last_non_zero_none h, h⟩
  · right
    push_neg at h
    rcases h with ⟨ i, hi, h ⟩
    exact last_non_zero_some hi h

theorem last_non_zero_spec [LawfulBEq R] {p : UniPoly R} {k} :
  p.last_non_zero = some k
  → p.coeffs[k] ≠ 0 ∧ (∀ j, (hj : j < p.size) → j > k → p.coeffs[j] = 0)
:= by
  intro (h : p.last_non_zero = some k)
  constructor
  · by_contra
    have h : p.coeffs[k] != 0 := Array.findIdxRev?_def h
    rwa [‹p.coeffs[k] = 0›, bne_self_eq_false, Bool.false_eq_true] at h
  · intro j hj j_gt_k
    have h : ¬(p.coeffs[j] != 0) := Array.findIdxRev?_maximal h ⟨ j, hj ⟩ j_gt_k
    rwa [bne_iff_ne, ne_eq, not_not] at h

-- the property of `last_non_zero_spec` uniquely identifies an element,
-- and that allows us to prove the reverse as well
def last_non_zero_prop {p : UniPoly R} (k: Fin p.size) : Prop :=
  p.coeffs[k] ≠ 0 ∧ (∀ j, (hj : j < p.size) → j > k → p.coeffs[j] = 0)

lemma last_non_zero_unique {p : UniPoly Q} {k k' : Fin p.size} :
  last_non_zero_prop k → last_non_zero_prop k' → k = k'
:= by
  suffices weaker : ∀ k k', last_non_zero_prop k → last_non_zero_prop k' → k ≤ k' by
    intro h h'
    exact Fin.le_antisymm (weaker k k' h h') (weaker k' k h' h)
  intro k k' ⟨ h_nonzero, h ⟩ ⟨ h_nonzero', h' ⟩
  by_contra k_not_le
  have : p.coeffs[k] = 0 := h' k k.is_lt (Nat.lt_of_not_ge k_not_le)
  contradiction

theorem last_non_zero_some_iff [LawfulBEq R]  {p : UniPoly R} {k} :
  p.last_non_zero = some k ↔ (p.coeffs[k] ≠ 0 ∧ (∀ j, (hj : j < p.size) → j > k → p.coeffs[j] = 0))
:= by
  constructor
  · apply last_non_zero_spec
  intro h_prop
  have ⟨ k', h_some'⟩ := last_non_zero_some k.is_lt h_prop.left
  have k_is_k' := last_non_zero_unique (last_non_zero_spec h_some') h_prop
  rwa [← k_is_k']

theorem size_eq_degree (p : UniPoly R) : p.trim.size = p.degree := by
  unfold trim degree
  match h : p.last_non_zero with
  | none => simp
  | some i => simp [Fin.is_lt, Nat.succ_le_of_lt]

theorem size_le_size (p : UniPoly R) : p.trim.size ≤ p.size := by
  unfold trim
  match h : p.last_non_zero with
  | none => simp
  | some i => simp [Array.size_extract]

theorem coeff_eq_getD_lt [LawfulBEq R] {p : UniPoly R} {i} (hi: i < p.size) :
  p.trim.coeffs.getD i 0 = p.coeffs[i] := by
  unfold trim last_non_zero
  by_cases h: ∀ a ∈ p.coeffs, ¬ (a != 0)
  · rw [Array.findIdxRev?_eq_none h]
    simp [Array.getElem?_eq]
    set a := p.coeffs[i]
    specialize h a (Array.getElem_mem hi)
    rw [bne_iff_ne, ne_eq, not_not] at h
    exact Eq.symm h
  · have h' : ∃ a ∈ p.coeffs, a != 0 := by push_neg at h; assumption
    obtain ⟨ k, hk ⟩ := Array.findIdxRev?_eq_some h'
    simp [hk]
    -- split between i > k and i <= k
    have h_size : k + 1 = (p.coeffs.extract 0 (k + 1)).size := by
      simp [Array.size_extract]
      exact Nat.succ_le_of_lt k.is_lt
    rcases (Nat.lt_or_ge k i) with hik | hik
    · have hik' : i ≥ (p.coeffs.extract 0 (k + 1)).size := by linarith
      rw [Array.getElem?_eq_none hik', Option.getD_none]
      have h_zero := Array.findIdxRev?_maximal hk ⟨ i, hi ⟩ hik
      simp at h_zero
      rw [‹p.coeffs[i] = 0›]
    · have hik' : i < (p.coeffs.extract 0 (k + 1)).size := by linarith
      rw [Array.getElem?_eq_getElem hik', Option.getD_some, Array.getElem_extract]
      simp only [zero_add]

theorem coeff_eq_getD [LawfulBEq R] (p : UniPoly R) (i : ℕ) :
  p.trim.coeffs.getD i 0 = p.coeffs.getD i 0 := by
  rcases (Nat.lt_or_ge i p.size) with hi | hi
  · rw [coeff_eq_getD_lt hi]
    simp [hi]
  · have hi' : i ≥ p.trim.size := by linarith [size_le_size p]
    simp [hi, hi']

lemma getD_eq_getElem {p : UniPoly Q} {i} (hp : i < p.size) :
  p.coeffs.getD i 0 = p.coeffs[i] := by
  simp [hp]

def equiv (p q : UniPoly R) : Prop :=
  ∀ i, p.coeffs.getD i 0 = q.coeffs.getD i 0

lemma getD_eq_zero {p : UniPoly Q} :
    (∀ i, (hi : i < p.size) → p.coeffs[i] = 0) ↔ ∀ i, p.coeffs.getD i 0 = 0
:= by
  constructor <;> intro h i
  · cases Nat.lt_or_ge i p.size <;> simp [h, *]
  · intro hi; specialize h i; simp [hi] at h; assumption

lemma eq_degree_of_equiv [LawfulBEq R] {p q : UniPoly R} : equiv p q → p.degree = q.degree := by
  unfold equiv degree
  intro h_equiv
  rcases last_none_zero_cases p with ⟨ h_none, h_all_zero ⟩ | h_some
  · rw [h_none]
    have h_zero_p : ∀ i, p.coeffs.getD i 0 = 0 := getD_eq_zero.mp h_all_zero
    have h_zero_q : ∀ i, q.coeffs.getD i 0 = 0 := by intro i; rw [← h_equiv, h_zero_p]
    have h_none_q : q.last_non_zero = none := last_non_zero_none (getD_eq_zero.mpr h_zero_q)
    rw [h_none_q]
  obtain ⟨ k, h_some_p ⟩ := h_some
  have h_equiv_k := h_equiv k
  have ⟨ h_nonzero_p, h_max_p ⟩ := last_non_zero_spec h_some_p
  have k_lt_q : k < q.size := by
    rcases Nat.lt_or_ge k q.size with h_lt | h_ge
    · exact h_lt
    simp [h_ge] at h_equiv_k
    contradiction
  simp [k_lt_q] at h_equiv_k
  have h_nonzero_q : q.coeffs[k.val] ≠ 0 := by rwa [← h_equiv_k]
  have h_max_q : ∀ j, (hj : j < q.size) → j > k → q.coeffs[j] = 0 := by
    intro j hj j_gt_k
    have h_eq := h_equiv j
    simp [hj] at h_eq
    rw [← h_eq]
    rcases Nat.lt_or_ge j p.size with hj | hj
    · simp [hj, h_max_p j hj j_gt_k]
    · simp [hj]
  have h_some_q : q.last_non_zero = some ⟨ k, k_lt_q ⟩ :=
    last_non_zero_some_iff.mpr ⟨ h_nonzero_q, h_max_q ⟩
  rw [h_some_p, h_some_q]

theorem eq_of_equiv [LawfulBEq R] {p q : UniPoly R} : equiv p q → p.trim = q.trim := by
  unfold equiv
  intro h
  ext
  show p.trim.size = q.trim.size
  · rw [size_eq_degree, size_eq_degree]
    apply eq_degree_of_equiv h
  rw [← getD_eq_getElem, ← getD_eq_getElem]
  rw [coeff_eq_getD, coeff_eq_getD, h _]

end Trim

section Operations

variable {S : Type*}

-- p(x) = a_0 + a_1 x + a_2 x^2 + ... + a_n x^n

-- eval₂ f x p = f(a_0) + f(a_1) x + f(a_2) x^2 + ... + f(a_n) x^n

/-- Evaluates a `UniPoly` at a given value, using a ring homomorphism `f: R →+* S`. -/
def eval₂ [Semiring S] (f : R →+* S) (x : S) (p : UniPoly R) : S :=
  p.coeffs.zipWithIndex.foldl (fun acc ⟨a, i⟩ => acc + f a * x ^ i) 0

/-- Evaluates a `UniPoly` at a given value. -/
def eval (x : R) (p : UniPoly R) : R :=
  p.eval₂ (RingHom.id R) x

/-- Addition of two `UniPoly`s. Defined as the pointwise sum of the underlying coefficient arrays
  (properly padded with zeroes). -/
def add_raw (p q : UniPoly R) : UniPoly R :=
  let ⟨p', q'⟩ := Array.matchSize p.coeffs q.coeffs 0
  .mk (Array.zipWith p' q' (· + ·) )

/-- Addition of two `UniPoly`s. -/
def add (p q : UniPoly R) : UniPoly R :=
  add_raw p q |> trim

/-- Scalar multiplication of `UniPoly` by an element of `R`. -/
def smul (r : R) (p : UniPoly R) : UniPoly R :=
  .mk (Array.map (fun a => r * a) p.coeffs)

def nsmul_raw (n : ℕ) (p : UniPoly R) : UniPoly R :=
  .mk (Array.map (fun a => n * a) p.coeffs)

/-- Scalar multiplication of `UniPoly` by a natural number. -/
def nsmul (n : ℕ) (p : UniPoly R) : UniPoly R :=
  nsmul_raw n p |> trim

/-- Negation of a `UniPoly`. -/
def neg [Ring R] (p : UniPoly R) : UniPoly R :=
  ⟨ p.coeffs.map (fun a => -a) ⟩

/-- Subtraction of two `UniPoly`s. -/
def sub [Ring R] (p q : UniPoly R) : UniPoly R := p.add q.neg

/-- Multiplication of a `UniPoly` by `X ^ i`, i.e. pre-pending `i` zeroes to the
underlying array of coefficients. -/
def mulPowX (i : Nat) (p : UniPoly R) : UniPoly R := .mk (Array.replicate i 0 ++ p.coeffs)

/-- Multiplication of a `UniPoly` by `X`, reduces to `mulPowX 1`. -/
@[reducible] def mulX (p : UniPoly R) : UniPoly R := p.mulPowX 1

/-- Multiplication of two `UniPoly`s, using the naive `O(n^2)` algorithm. -/
def mul (p q : UniPoly R) : UniPoly R :=
  p.coeffs.zipWithIndex.foldl (fun acc ⟨a, i⟩ => acc.add <| (smul a q).mulPowX i) (C 0)

/-- Exponentiation of a `UniPoly` by a natural number `n` via repeated multiplication. -/
def pow (p : UniPoly R) (n : Nat) : UniPoly R := (mul p)^[n] (C 1)

-- TODO: define repeated squaring version of `pow`

instance : Zero (UniPoly R) := ⟨UniPoly.mk #[]⟩
instance : One (UniPoly R) := ⟨UniPoly.C 1⟩
instance : Add (UniPoly R) := ⟨UniPoly.add⟩
instance : SMul R (UniPoly R) := ⟨UniPoly.smul⟩
instance : SMul ℕ (UniPoly R) := ⟨nsmul⟩
instance [Ring R] : Neg (UniPoly R) := ⟨UniPoly.neg⟩
instance [Ring R] : Sub (UniPoly R) := ⟨UniPoly.sub⟩
instance : Mul (UniPoly R) := ⟨UniPoly.mul⟩
instance : Pow (UniPoly R) Nat := ⟨UniPoly.pow⟩
instance : NatCast (UniPoly R) := ⟨fun n => UniPoly.C (n : R)⟩
instance [Ring R] : IntCast (UniPoly R) := ⟨fun n => UniPoly.C (n : R)⟩

/-- Convert a `UniPoly` to a `Polynomial`. -/
noncomputable def toPoly (p : UniPoly R) : Polynomial R :=
  p.eval₂ Polynomial.C Polynomial.X

/-- Return a bound on the degree of a `UniPoly` as the size of the underlying array
(and `⊥` if the array is empty). -/
def degreeBound (p : UniPoly R) : WithBot Nat :=
  match p.coeffs.size with
  | 0 => ⊥
  | .succ n => n

/-- Convert `degreeBound` to a natural number by sending `⊥` to `0`. -/
def natDegreeBound (p : UniPoly R) : Nat :=
  (degreeBound p).getD 0


/-- Check if a `UniPoly` is monic, i.e. its leading coefficient is 1. -/
def monic (p : UniPoly R) : Bool := p.leadingCoeff == 1

-- TODO: remove dependence on `BEq` for division and modulus

/-- Division and modulus of `p : UniPoly R` by a monic `q : UniPoly R`. -/
def divModByMonicAux [Field R] (p : UniPoly R) (q : UniPoly R) :
    UniPoly R × UniPoly R :=
  go (p.size - q.size) p q
where
  go : Nat → UniPoly R → UniPoly R → UniPoly R × UniPoly R
  | 0, p, _ => ⟨0, p⟩
  | n+1, p, q =>
      let k := p.coeffs.size - q.coeffs.size -- k should equal n, this is technically unneeded
      let q' := C p.leadingCoeff * (q * X.pow k)
      let p' := (p - q').trim
      let (e, f) := go n p' q
      -- p' = q * e + f
      -- Thus p = p' + q' = q * e + f + p.leadingCoeff * q * X^n
      -- = q * (e + p.leadingCoeff * X^n) + f
      ⟨e + C p.leadingCoeff * X^k, f⟩

/-- Division of `p : UniPoly R` by a monic `q : UniPoly R`. -/
def divByMonic [Field R] (p : UniPoly R) (q : UniPoly R) :
    UniPoly R :=
  (divModByMonicAux p q).1

/-- Modulus of `p : UniPoly R` by a monic `q : UniPoly R`. -/
def modByMonic [Field R] (p : UniPoly R) (q : UniPoly R) :
    UniPoly R :=
  (divModByMonicAux p q).2

/-- Division of two `UniPoly`s. -/
def div [Field R] (p q : UniPoly R) : UniPoly R :=
  (C (q.leadingCoeff)⁻¹ • p).divByMonic (C (q.leadingCoeff)⁻¹ * q)

/-- Modulus of two `UniPoly`s. -/
def mod [Field R] (p q : UniPoly R) : UniPoly R :=
  (C (q.leadingCoeff)⁻¹ • p).modByMonic (C (q.leadingCoeff)⁻¹ * q)

instance [Field R] : Div (UniPoly R) := ⟨UniPoly.div⟩
instance [Field R] : Mod (UniPoly R) := ⟨UniPoly.mod⟩

/-- Pseudo-division of a `UniPoly` by `X`, which shifts all non-constant coefficients
to the left by one. -/
def divX (p : UniPoly R) : UniPoly R := ⟨p.coeffs.extract 1 p.size⟩

@[simp] theorem zero_def : (0 : UniPoly Q) = ⟨#[]⟩ := rfl

variable (p q r : UniPoly R)

-- some helper lemmas to characterize p + q

theorem matchSize_size_eq {p q : UniPoly Q} :
  let (p', q') := Array.matchSize p.coeffs q.coeffs 0
  p'.size = q'.size := by
  apply List.matchSize_length_eq

theorem matchSize_size {p q : UniPoly Q} :
  let (p', _) := Array.matchSize p.coeffs q.coeffs 0
  p'.size = max p.size q.size := by
  apply List.matchSize_length

theorem zipWith_size {R} {f : R → R → R} {a b : Array R} :
  a.size = b.size → (Array.zipWith a b f).size = a.size := by
  simp; omega

-- TODO generalize to matchSize + zipWith f for any f
theorem add_size {p q : UniPoly Q} : (add_raw p q).size = max p.size q.size := by
  show (Array.zipWith _ _ _ ).size = max p.size q.size
  rw [zipWith_size matchSize_size_eq, matchSize_size]

-- TODO generalize to matchSize + zipWith f for any f
theorem add_coeff {p q : UniPoly Q} {i: ℕ} (hi: i < (add_raw p q).size) :
  (add_raw p q).coeffs[i] = p.coeffs.getD i 0 + q.coeffs.getD i 0
:= by
  simp [add_raw]
  rw [List.getElem_matchSize_1, List.getElem_matchSize_2]
  repeat rw [Array.getElem?_eq_toList]

-- TODO generalize to matchSize + zipWith f for any f
theorem add_coeff? (p q : UniPoly Q) (i: ℕ) :
  (add_raw p q).coeffs.getD i 0 = p.coeffs.getD i 0 + q.coeffs.getD i 0
:= by
  rcases (Nat.lt_or_ge i (add_raw p q).coeffs.size) with h_lt | h_ge
  · rw [← add_coeff h_lt]; simp [h_lt]
  have h_lt' : i ≥ max p.size q.size := by rwa [← add_size]
  have h_p : i ≥ p.size := by omega
  have h_q : i ≥ q.size := by omega
  simp [h_ge, h_p, h_q]

-- TODO generalize to matchSize + zipWith f for any f
lemma trim_add_trim [LawfulBEq R] (p q : UniPoly R) : p.trim + q = p + q := by
  apply Trim.eq_of_equiv
  intro i
  rw [add_coeff?, add_coeff?, Trim.coeff_eq_getD]

-- algebra theorems about add

theorem add_comm : p + q = q + p := by
  apply congrArg trim
  ext
  · simp only [add_size]; omega
  · simp only [add_coeff]
    apply _root_.add_comm

def canonical (p : UniPoly R) := p = p.trim

@[simp] theorem zero_add (hp : p.canonical) : 0 + p = p := by
  rw (occs := .pos [2]) [hp]
  apply congrArg trim
  ext <;> simp [add_size, add_coeff, *]

@[simp] theorem add_zero (hp : p.canonical) : p + 0 = p := by
  rw [add_comm, zero_add p hp]

theorem add_assoc [LawfulBEq R] : p + q + r = p + (q + r) := by
  show (add_raw p q).trim + r = p + (add_raw q r).trim
  rw [trim_add_trim, add_comm p, trim_add_trim, add_comm _ p]
  apply congrArg trim
  ext i
  · simp only [add_size]; omega
  · simp only [add_coeff, add_coeff?]
    apply _root_.add_assoc

theorem nsmul_zero [LawfulBEq R] (p : UniPoly R) : nsmul 0 p = 0 := by
  suffices (nsmul_raw 0 p).last_non_zero = none by simp [nsmul, trim, *]
  unfold last_non_zero
  apply Array.findIdxRev?_eq_none
  intro a ha
  suffices a = 0 by simp [*]
  rw [nsmul_raw, Array.mem_map] at ha
  simp only [Nat.cast_zero, zero_mul] at ha
  tauto

theorem nsmul_succ (n : ℕ) (p: UniPoly R) :
  nsmul (n + 1) p = nsmul n p + p
:= by
  sorry

theorem neg_add_cancel [Ring R] (p : UniPoly R) : -p + p = 0 := by
  ext i
  · show ((-p + p).size : ℕ) = (0 : UniPoly R).size
    sorry -- not true
  · show ((-p + p).coeffs[i] : R) = (0 : UniPoly R).coeffs[i]
    sorry -- not true

instance [LawfulBEq R] : AddCommMonoid (UniPoly R) where
  add_assoc p q r := add_assoc p q r
  zero_add := sorry
  add_zero := sorry
  add_comm := add_comm
  nsmul := nsmul
  nsmul_zero := nsmul_zero
  nsmul_succ := nsmul_succ

instance [LawfulBEq R] [Ring R] : AddGroup (UniPoly R) where
  neg := neg
  sub := sub
  zsmul := zsmulRec
  neg_add_cancel := neg_add_cancel

instance [LawfulBEq R] [Ring R] : AddCommGroup (UniPoly R) where
  add_comm := add_comm

-- TODO: define `SemiRing` structure on `UniPoly`

end Operations


section Equiv

/-- An equivalence relation `equiv` on `UniPoly`s where `p ~ q` iff one is a
zero-padding of the other. -/
def equiv (p q : UniPoly R) : Prop :=
  match p.coeffs.matchSize q.coeffs 0 with
  | (p', q') => p' = q'

/-- Reflexivity of the equivalence relation. -/
@[simp] theorem equiv_refl (p : UniPoly Q) : equiv p p :=
  by simp [equiv, List.matchSize]

/-- Symmetry of the equivalence relation. -/
@[simp] theorem equiv_symm {p q : UniPoly Q} : equiv p q → equiv q p :=
  fun h => by simp [equiv] at *; exact Eq.symm h

open List in
/-- Transitivity of the equivalence relation. -/
@[simp] theorem equiv_trans {p q r : UniPoly Q} : equiv p q → equiv q r → equiv p r :=
  fun hpq hqr => by
    simp_all [equiv, Array.matchSize]
    have hpq' := (List.matchSize_eq_iff_forall_eq p.coeffs.toList q.coeffs.toList 0).mp hpq
    have hqr' := (List.matchSize_eq_iff_forall_eq q.coeffs.toList r.coeffs.toList 0).mp hqr
    have hpr' : ∀ (i : Nat), p.coeffs.toList.getD i 0 = r.coeffs.toList.getD i 0 :=
      fun i => Eq.trans (hpq' i) (hqr' i)
    exact (List.matchSize_eq_iff_forall_eq p.coeffs.toList r.coeffs.toList 0).mpr hpr'

/-- The `UniPoly.equiv` is indeed an equivalence relation. -/
instance instEquivalenceEquiv : Equivalence (equiv (R := R)) where
  refl := equiv_refl
  symm := equiv_symm
  trans := equiv_trans

/-- The `Setoid` instance for `UniPoly R` induced by `UniPoly.equiv`. -/
instance instSetoidUniPoly: Setoid (UniPoly R) where
  r := equiv
  iseqv := instEquivalenceEquiv

/-- The quotient of `UniPoly R` by `UniPoly.equiv`. This will be shown to be equivalent to
  `Polynomial R`. -/
def QuotientUniPoly := Quotient (@instSetoidUniPoly R _)

-- TODO: show that operations on `UniPoly` descend to `QuotientUniPoly`



end Equiv

namespace Lagrange

-- unique polynomial of degree n that has nodes at ω^i for i = 0, 1, ..., n-1
def nodal {R : Type*} [Semiring R] (n : ℕ) (ω : R) : UniPoly R := sorry
  -- .mk (Array.range n |>.map (fun i => ω^i))

/--
This function produces the polynomial which is of degree n and is equal to r i at ω^i for i = 0, 1,
..., n-1.
-/
def interpolate {R : Type*} [Semiring R] (n : ℕ) (ω : R) (r : Vector R n) : UniPoly R := sorry
  -- .mk (Array.finRange n |>.map (fun i => r[i])) * nodal n ω

end Lagrange

end UniPoly

section Tropical
/-- This section courtesy of Junyan Xu -/

instance : LinearOrderedAddCommMonoidWithTop (OrderDual (WithBot ℕ)) where
  __ : LinearOrderedAddCommMonoid (OrderDual (WithBot ℕ)) := inferInstance
  __ : Top (OrderDual (WithBot ℕ)) := inferInstance
  le_top _ := bot_le (α := WithBot ℕ)
  top_add' x := WithBot.bot_add x


noncomputable instance (R) [Semiring R] : Semiring (Polynomial R × Tropical (OrderDual (WithBot ℕ)))
  := inferInstance

noncomputable instance (R) [CommSemiring R] : CommSemiring
    (Polynomial R × Tropical (OrderDual (WithBot ℕ))) := inferInstance


def TropicallyBoundPoly (R) [Semiring R] : Subsemiring
    (Polynomial R × Tropical (OrderDual (WithBot ℕ))) where
  carrier := {p | p.1.degree ≤ OrderDual.ofDual p.2.untrop}
  mul_mem' {p q} hp hq := (p.1.degree_mul_le q.1).trans (add_le_add hp hq)
  one_mem' := Polynomial.degree_one_le
  add_mem' {p q} hp hq := (p.1.degree_add_le q.1).trans (max_le_max hp hq)
  zero_mem' := Polynomial.degree_zero.le


noncomputable def UniPoly.toTropicallyBoundPolynomial {R : Type} [Semiring R] (p : UniPoly R) :
    Polynomial R × Tropical (OrderDual (WithBot ℕ)) :=
  (UniPoly.toPoly p, Tropical.trop (OrderDual.toDual (UniPoly.degreeBound p)))

def degBound (b: WithBot ℕ) : ℕ := match b with
  | ⊥ => 0
  | some n => n + 1

def TropicallyBoundPolynomial.toUniPoly {R : Type} [Semiring R]
    (p : Polynomial R × Tropical (OrderDual (WithBot ℕ))) : UniPoly R :=
  match p with
  | (p, n) => UniPoly.mk (Array.range (degBound n.untrop) |>.map (fun i => p.coeff i))

noncomputable def Equiv.UniPoly.TropicallyBoundPolynomial {R : Type} [BEq R] [Semiring R] :
    UniPoly R ≃+* Polynomial R × Tropical (OrderDual (WithBot ℕ)) where
      toFun := UniPoly.toTropicallyBoundPolynomial
      invFun := TropicallyBoundPolynomial.toUniPoly
      left_inv := by sorry
      right_inv := by sorry
      map_mul' := by sorry
      map_add' := by sorry

end Tropical
