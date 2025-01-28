/-
Copyright (c) 2025 ZKLib Contributors. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Quang Dao
-/

import ZKLib.Data.MlPoly.Basic
import ZKLib.Data.MvPolynomial.Notation
-- import Mathlib.RingTheory.MvPolynomial.Basic

/-!
  # Equivalence between `MlPoly` and multilinear polynomials in `MvPolynomial`
-/

open MvPolynomial

#check MvPolynomial.restrictDegree

variable {R : Type*} [CommSemiring R] {n : ℕ}

-- def MlPolynomial R n := MvPolynomial.restrictDegree (Fin n) R 1

namespace MlPoly

def toSpec (p : MlPoly R n) : R⦃≤ 1⦄[X Fin n] :=
  sorry

def ofSpec (p : R⦃≤ 1⦄[X Fin n]) : MlPoly R n :=
  sorry

def equivSpec : MlPoly R n ≃ R⦃≤ 1⦄[X Fin n] where
  toFun := toSpec
  invFun := ofSpec
  left_inv := sorry
  right_inv := sorry

#check MvPolynomial.eval₂

variable {S : Type*} [CommSemiring S]

theorem equivSpec_add (p q : MlPoly R n) :
  (p + q).toSpec = p.toSpec + q.toSpec :=
  sorry

theorem equivSpec_eval₂ (f : R →+* S) (p : MlPoly R n) (x : Vector S n) :
    p.eval₂ f x = p.toSpec.val.eval₂ f x.get :=
  sorry

-- TODO: fill in these theorems and more

end MlPoly

namespace MlPolyEval

-- TODO: state the equivalence between `MlPolyEval` and `MlPoly`, via going from the coefficients to
-- the monomial basis

end MlPolyEval
