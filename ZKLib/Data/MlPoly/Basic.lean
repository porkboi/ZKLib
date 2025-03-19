/-
Copyright (c) 2024 ZKLib Contributors. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Quang Dao
-/

-- import Mathlib.Data.Matrix.Mul
import Mathlib.RingTheory.MvPolynomial.Basic
import Mathlib.Data.Matrix.Basic
import Mathlib.Data.Matrix.Kronecker
import Mathlib.Data.Vector.Basic
import Mathlib.Data.Array.Basic
import Mathlib.Data.Finset.Basic

/-!
  # Multilinear Polynomials

  This file defines computable representations of **multilinear polynomials**.

  The first representation is by their coefficients, and the second representation is by their
  evaluations over the Boolean hypercube `{0,1}^n`. Both representations are defined as `Array`s of
  size `2^n`, where `n` is the number of variables. We will define operations on these
  representations, and prove equivalence between them, and with the standard Mathlib definition of
  multilinear polynomials, which is the type `R⦃≤ 1⦄[X Fin n]` (notation for
  `MvPolynomial.restrictDegree (Fin n) R 1`).
-/

namespace Vector

def nil {α} : Vector α 0 := ⟨#[], rfl⟩

def cons {α} {n : ℕ} (hd : α) (tl : Vector α n) : Vector α (n + 1) :=
  ⟨⟨hd :: tl.toArray.toList⟩, by simp⟩

def cases {α} {motive : {n : ℕ} → Vector α n → Sort*} (vNil : motive nil)
  (vCons : {n : ℕ} → (hd : α) → (tl : Vector α n) → motive (cons hd tl)) {m : ℕ} :
    (v : Vector α m) → motive v := match hm : m with
  | 0 => fun v => match v with | ⟨⟨[]⟩, rfl⟩ => vNil
  | n + 1 => fun v => match hv : v with
    | ⟨⟨hd :: tl⟩, hSize⟩ => @vCons n hd ⟨⟨tl⟩, by simpa using hSize⟩

def induction {α} {motive : {n : ℕ} → Vector α n → Sort*} (vNil : motive nil)
  (vCons : {n : ℕ} → (hd : α) → (tl : Vector α n) → motive tl → motive (cons hd tl)) {m : ℕ} :
    (v : Vector α m) → motive v := by induction m with
  | zero => exact fun v => match v with | ⟨⟨[]⟩, rfl⟩ => vNil
  | succ n ih => exact fun v => match v with
    | ⟨⟨hd :: tl⟩, hSize⟩ =>
      @vCons n hd ⟨⟨tl⟩, by simpa using hSize⟩ (ih ⟨⟨tl⟩, by simpa using hSize⟩)

def cases₂ {α β} {motive : {n : ℕ} → Vector α n → Vector β n → Sort*} (vNil : motive nil nil)
  (vCons : {n : ℕ} → (hd : α) → (tl : Vector α n) → (hd' : β) → (tl' : Vector β n) →
    motive (cons hd tl) (cons hd' tl')) {m : ℕ} :
    (v : Vector α m) → (v' : Vector β m) → motive v v' := match hm : m with
  | 0 => fun v v' => match v, v' with | ⟨⟨[]⟩, rfl⟩, ⟨⟨[]⟩, rfl⟩ => vNil
  | n + 1 => fun v v' => match hv : v, hv' : v' with
    | ⟨⟨hd :: tl⟩, hSize⟩, ⟨⟨hd' :: tl'⟩, hSize'⟩ =>
      @vCons n hd ⟨⟨tl⟩, by simpa using hSize⟩ hd' ⟨⟨tl'⟩, by simpa using hSize'⟩

@[elab_as_elim]
def induction₂ {α β} {motive : {n : ℕ} → Vector α n → Vector β n → Sort*} (vNil : motive nil nil)
  (vCons : {n : ℕ} → (hd : α) → (tl : Vector α n) → (hd' : β) → (tl' : Vector β n) →
    motive tl tl' → motive (cons hd tl) (cons hd' tl')) {m : ℕ} :
    (v : Vector α m) → (v' : Vector β m) → motive v v' := by induction m with
  | zero => exact fun v v' => match v, v' with | ⟨⟨[]⟩, rfl⟩, ⟨⟨[]⟩, rfl⟩ => vNil
  | succ n ih => exact fun v v' => match hv : v, hv' : v' with
    | ⟨⟨hd :: tl⟩, hSize⟩, ⟨⟨hd' :: tl'⟩, hSize'⟩ =>
      @vCons n hd ⟨⟨tl⟩, by simpa using hSize⟩ hd' ⟨⟨tl'⟩, by simpa using hSize'⟩
      (ih ⟨⟨tl⟩, by simpa using hSize⟩ ⟨⟨tl'⟩, by simpa using hSize'⟩)

variable {R : Type*} [Mul R] [AddCommMonoid R] {n : ℕ}

/-- Inner product between two vectors of the same size. Should be faster than `_root_.dotProduct`
    due to efficient operations on `Array`s. -/
def dotProduct (a b : Vector R n) : R :=
  a.zipWith (· * ·) b |>.foldl (· + ·) 0

scoped notation:80 a " *ᵥ " b => dotProduct a b

def dotProduct_cons (a : R) (b : Vector R n) (c : R) (d : Vector R n) :
  dotProduct (cons a b) (cons c d) = a * c + dotProduct b d := by
  simp [dotProduct, cons, get, foldl]
  sorry

def dotProduct_root_cons (a : R) (b : Vector R n) (c : R) (d : Vector R n) :
    _root_.dotProduct (cons a b).get (cons c d).get = a * c + _root_.dotProduct b.get d.get := by
  sorry

theorem dotProduct_eq_matrix_dotProduct (a b : Vector R n) :
    dotProduct a b = _root_.dotProduct a.get b.get := by
  refine induction₂ ?_ (fun hd tl hd' tl' ih => ?_) a b
  · simp [nil, dotProduct, _root_.dotProduct]
  · rw [dotProduct_cons, dotProduct_root_cons, ih]

end Vector

/-- `MlPoly n R` is the type of multilinear polynomials in `n` variables over a ring `R`. It is
    represented by its coefficients as an `Array` of size `2^n`. -/
def MlPoly (R : Type*) (n : ℕ) := Vector R (2 ^ n)

/-- `MlPolyEval n R` is the type of multilinear polynomials in `n` variables over a ring `R`. It is
    represented by its evaluations over the Boolean hypercube `{0,1}^n`. -/
def MlPolyEval (R : Type*) (n : ℕ) := Vector R (2 ^ n)

variable {R : Type*} {n : ℕ}

#check finFunctionFinEquiv

#check Pi.single

namespace MlPoly

/-! ### TODO: define `add`, `smul`, `nsmul`, `zsmul`, `eval₂`, `eval` -/

instance inhabited [Inhabited R] : Inhabited (MlPoly R n) := by simp [MlPoly]; infer_instance

-- Conform a list of coefficients to a `MlPoly` with a given number of variables
-- May either pad with zeros or truncate
def ofArray [Zero R] (coeffs : Array R) (n : ℕ): MlPoly R n :=
  .ofFn (fun i => if h : i.1 < coeffs.size then coeffs.get i h else 0)

-- Create a zero polynomial over n variables
def zero [Zero R] : MlPoly R n := ofArray (Array.mkArray (2 ^ n) 0) n

/-- Add two `MlPoly`s -/
def add [Add R] (p q : MlPoly R n) : MlPoly R n := Vector.zipWith (· + ·) p q

/-- Negation of a `MlPoly` -/
def neg [Neg R] (p : MlPoly R n) : MlPoly R n := p.map (fun a => -a)

/-- Scalar multiplication of a `MlPoly` -/
def smul [Mul R] (r : R) (p : MlPoly R n) : MlPoly R n := p.map (fun a => r * a)

/-- Scalar multiplication of a `MlPoly` by a natural number -/
def nsmul [SMul ℕ R] (m : ℕ) (p : MlPoly R n) : MlPoly R n := p.map (fun a => m • a)

/-- Scalar multiplication of a `MlPoly` by an integer -/
def zsmul [SMul ℤ R] (m : ℤ) (p : MlPoly R n) : MlPoly R n := p.map (fun a => m • a)

/-- TODO : fill out this instance -/
instance [AddCommMonoid R] : AddCommMonoid (MlPoly R n) :=
  {
    add := add
    add_assoc := by sorry
    add_comm := by sorry
    zero := zero
    zero_add := by sorry
    add_zero := by sorry
    nsmul := nsmul
    nsmul_zero := by sorry
    nsmul_succ := by sorry
  }

/-- TODO : fill out this instance -/
instance [Semiring R] : Module R (MlPoly R n) where
  smul := smul
  one_smul := by sorry
  mul_smul := by sorry
  smul_zero := by sorry
  smul_add := by sorry
  add_smul := by sorry
  zero_smul := by sorry

-- Generate the Lagrange basis for evaluation point r
-- First, a helper function
-- def lagrangeBasisAux (r : Array R) (evals : Array R) (ell : Nat) (j : Nat) (size : Nat) :
--    Array R :=
--   if j >= ell then
--     evals
--   else
--     let size := size * 2
--     let evals :=
--       (Array.range size).reverse.foldl
--         (fun evals i =>
--           if i % 2 == 1 then
--             let scalar := evals.get! (i / 2)
--             let evals := evals.set! i (scalar * r.get! j)
--             let evals := evals.set! (i - 1) (scalar - evals.get! i)
--             evals
--           else evals)
--         evals
--     lagrangeBasisAux r evals ell (j + 1) size
-- termination_by (ell - j)

variable [CommSemiring R]

/-- TODO: define this in a functional way -/
def lagrangeBasis (r : Vector R n) : Vector R (2 ^ n) := sorry
  -- let ell := r.size
  -- let evals := Array.mkArray (2 ^ ell) 1
  -- lagrangeBasisAux r evals ell 0 1

variable {S : Type*} [CommSemiring S]

def map (f : R →+* S) (p : MlPoly R n) : MlPoly S n :=
  Vector.map (fun a => f a) p

/-- Evaluate a `MlPoly` at a point -/
def eval (p : MlPoly R n) (x : Vector R n) : R :=
  Vector.dotProduct p (lagrangeBasis x)

def eval₂ (p : MlPoly R n) (f : R →+* S) (x : Vector S n) : S := eval (map f p) x

-- Theorems about evaluations

-- Evaluation at a point in the Boolean hypercube is equal to the corresponding evaluation in the
-- array
-- theorem eval_eq_eval_array (p : MlPoly R) (x : Array Bool) (h : x.size = p.nVars): eval p
-- x.map (fun b => b) = p.evals.get! (x.foldl (fun i elt => i * 2 + elt) 0) := by unfold eval unfold
-- dotProduct simp [↓reduceIte, h] sorry

open matrix

variables {α : Type*} [comm_ring α] [decidable_eq α]

def hadamard_matrix : Π (n : ℕ), matrix (fin (2^n)) (fin (2^n)) ℝ
| 0 := !![1]
| (n+1) := let H := hadamard_matrix n in
  from_blocks H H H (-H)

def walsh_hadamard_transform (c : ℝ^(fin (2^n))) : ℝ^(fin (2^n)) :=
  hadamard_matrix n ⬝ c

def multilinear_polynomial_eval (c : ℝ^(fin (2^n))) (z : ℝ^n) : ℝ :=
  ∑ b in finset.univ, c b * ∏ i, z i ^ (b i)

theorem walsh_hadamard_eval (c : ℝ^(fin (2^n))) (z : ℝ^n) :
  walsh_hadamard_transform c = multilinear_polynomial_eval c z :=
begin
  induction n with n ih,
  {
    simp [hadamard_matrix, walsh_hadamard_transform, multilinear_polynomial_eval],
    refl },
  {
    simp [hadamard_matrix, walsh_hadamard_transform, multilinear_polynomial_eval],
    let c₀ := λ b : fin (2^n), c (fin.append_bit0 b),
    let c₁ := λ b : fin (2^n), c (fin.append_bit1 b),
    have Hn := ih c₀ z,
    have Hn' := ih c₁ z,
    rw [Hn, Hn'],
    simp [matrix.from_blocks, mul_vec],
    ext i,
    cases i using fin.cases with i₀ i₁,
    {
      simp [c₀, c₁, fin.append_bit0, fin.append_bit1],
      rw [mul_add, mul_sub],
      ring },
    {
      simp [c₀, c₁, fin.append_bit0, fin.append_bit1],
      rw [mul_add, mul_sub],
      ring } }
end

end MlPoly

section MlPolyEval

-- TODO: define the functions below in a functional way (easier to prove theorems about)

-- This function converts multilinear representation in the evaluation basis to the monomial basis
-- This is also called the Walsh-Hadamard transform (either that or the inverse)

-- def walshHadamardTransform (a : Array R) (n : ℕ) (h : ℕ) : Array R :=
--   if h < n then
--     let a := (Array.range (2 ^ n)).foldl (fun a i =>
--       if i &&& (2 ^ h) == 0 then
--         let u := a.get! i
--         let v := a.get! (i + (2 ^ h))
--         (a.set! i (u + v)).set! (i + (2 ^ h)) (v - u)
--       else
--         a
--     ) a
--     walshHadamardTransform a n (h + 1)
--   else
--     a

-- def evalToMonomial (a : Array R) : Array R := walshHadamardTransform a (Nat.clog 2 a.size) 0

-- def invWalshHadamardTransform (a : Array R) (n : ℕ) (h : ℕ) : Array R :=
--   if h < n then
--     let a := (Array.range (2 ^ n)).foldl (fun a i =>
--       if i &&& (2 ^ h) == 0 then
--         let u := a.get! i
--         let v := a.get! (i + (2 ^ h))
--         (a.set! i (u + v)).set! (i + (2 ^ h)) (v - u)
--       else
--         a
--     ) a
--     invWalshHadamardTransform a n (h + 1)
--   else
--     a

-- def monomialToEval (a : Array R) : Array R := invWalshHadamardTransform a (Nat.clog 2 a.size) 0

-- @[simp]
-- lemma evalToMonomial_size (a : Array R) : (evalToMonomial a).size = 2 ^ (Nat.clog 2 a.size) := by
--   unfold evalToMonomial
--   sorry

end MlPolyEval
