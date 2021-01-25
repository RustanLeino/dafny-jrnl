// -*- dafny-prover-local-args: ("/z3opt:smt.arith.nl=true" "/arith:1") -*-
module Arith {
  lemma div_mod_split(x: nat, k: nat)
      requires 0 < k
      ensures x == (x/k)*k + x%k
      ensures 0 <= x/k
      ensures x%k < k
  {}

  lemma mul_add_bound(x1: nat, x2: nat, x1_bound: nat, k:nat)
      requires 0 < k
      requires x1 < x1_bound
      requires x2 < k
      ensures x1*k + x2 < k*x1_bound
  {
      //assert x1 <= x1_bound-1;
      calc {
          x1 * k;
          <= (x1_bound-1)*k;
          == x1_bound*k-k;
      }
  }

  lemma mul_r_strictly_incr(x: int, y: int, k: int)
    requires 0 < k
    requires x < y
    ensures x*k < y*k
  {}

  lemma mul_r_incr(x: int, y: int, k:int)
    requires 0 < k
    requires x <= y
    ensures x*k <= y*k
  {}

  lemma mul_assoc(x: int, y: int, z: int)
    ensures x*(y*z) == (x * y) * z
  {}

  lemma mul_incr_auto()
    ensures forall x, y, k :: 0 < k && x < y ==> x*k < y*k
    ensures forall x, y, k :: 0 < k && x <= y ==> x*k <= y*k
  {}

  lemma mul_r_increasing(x1: nat, x2: nat)
  requires 0 < x2
  ensures x1 <= x1 * x2
  {}

  lemma mul_positive(x: nat, y: nat)
    ensures 0 <= x*y
  {}

  lemma mod_bound(x: nat, k: nat)
    requires 0 < k
    ensures x%k < k
  {}

  lemma mul_distr_add_l(x: int, y: int, z: int)
    ensures x*(y+z) == x*y + x*z
  {}

  lemma mul_distr_add_r(x: int, y: int, z: int)
    ensures (x+y)*z == x*z + y*z
  {}

  lemma div_incr(x: nat, y: nat, k: nat)
    requires 0 < k
    requires x < k * y
    ensures x / k < y
  {}

  lemma div_positive(x: nat, y: int)
    requires 0 < y
    ensures 0 <= x / y
  {}

  // TODO: prove these basic properties of mul, mod, div

  lemma {:axiom} mod_add(a: nat, b: nat, k: nat)
    requires 0 < k
    ensures (a + b) % k == (a%k + b%k) % k

  lemma {:axiom} mul_div_id(a: nat, k: nat)
    requires 0 < k
    ensures (a*k) / k == a

  lemma mul_mod(a: nat, k: nat)
    requires 0 < k
    ensures a * k % k == 0
  {
    div_mod_split(a*k, k);
    mul_div_id(a, k);
  }

  lemma zero_mod(k: int)
    requires k != 0
    ensures 0 % k == 0
  {}

  lemma mul_1(x: int)
    ensures x * 1 == x
  {}

  lemma mul_neg_1(x: int)
    ensures x * -1 == -x
  {}

}