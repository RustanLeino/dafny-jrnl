include "dirent.dfy"

module MemDirEntries
{
  import opened Std
  import opened DirEntries
  import opened Machine
  import opened ByteSlice
  import opened FsKinds
  import IntEncoding

  datatype MemDirEnt = MemDirEnt(name: Bytes, ino: Ino)
  {
    function val(): DirEnt
      reads name
      requires Valid()
    {
      DirEnt(name.data, ino)
    }

    predicate method used()
    {
      ino != 0
    }

    predicate Valid()
      reads name
    {
      && is_pathc(name.data)
    }
  }

  function mem_dirs_repr(s: seq<MemDirEnt>): set<object>
  {
    set i:nat | i < |s| :: s[i].name
  }

  lemma mem_dirs_repr_app(s1: seq<MemDirEnt>, s2: seq<MemDirEnt>)
    ensures mem_dirs_repr(s1 + s2) == mem_dirs_repr(s1) + mem_dirs_repr(s2)
  {
    forall o:object | o in mem_dirs_repr(s2)
      ensures o in mem_dirs_repr(s1 + s2)
    {
      var i:nat :| i < |s2| && s2[i].name == o;
      assert (s1 + s2)[|s1| + i].name == o;
    }

    forall o:object | o in mem_dirs_repr(s1)
      ensures o in mem_dirs_repr(s1 + s2)
    {
      var i:nat :| i < |s1| && s1[i].name == o;
      assert (s1 + s2)[i].name == o;
    }
  }

  function mem_seq_val(s: seq<MemDirEnt>): seq<DirEnt>
    reads mem_dirs_repr(s)
    requires forall i:nat | i < |s| :: s[i].Valid()
  {
    seq(|s|, (i:nat)
      reads mem_dirs_repr(s)
      requires i < |s|
      requires s[i].Valid() =>
      s[i].val())
  }

  lemma mem_seq_val_app(s1: seq<MemDirEnt>, s2: seq<MemDirEnt>)
    requires forall i:nat | i < |s1| :: s1[i].Valid()
    requires forall i:nat | i < |s2| :: s2[i].Valid()
    ensures mem_seq_val(s1 + s2) == mem_seq_val(s1) + mem_seq_val(s2)
  {}

  method NullTerminatedEqualSmaller(bs1: Bytes, bs2: Bytes) returns (p:bool)
    requires bs1.Valid() && bs2.Valid()
    requires bs1.Len() <= bs2.Len()
    ensures p == (decode_null_terminated(bs1.data) == decode_null_terminated(bs2.data))
  {
    var i: uint64 := 0;
    var len: uint64 := bs1.Len();
    while i < len
      invariant 0 <= i as nat <= |bs1.data|
      invariant bs1.data[..i] == bs2.data[..i]
      invariant decode_null_terminated(bs1.data) == bs1.data[..i] + decode_null_terminated(bs1.data[i..])
      invariant decode_null_terminated(bs2.data) == bs2.data[..i] + decode_null_terminated(bs2.data[i..])

    {
      var b1 := bs1.Get(i);
      var b2 := bs2.Get(i);
      if b1 == 0 || b2 == 0 {
        return b1 == b2;
      }
      assert b1 != 0 && b2 != 0;
      if b1 != b2 {
        assert decode_null_terminated(bs1.data)[i] == b1;
        assert decode_null_terminated(bs2.data)[i] == b2;
        return false;
      }
      i := i + 1;
    }
    if bs1.Len() == bs2.Len() {
      return true;
    }
    assert bs1.Len() < bs2.Len();
    var last := bs2.Get(bs1.Len());
    return last == 0;
  }

  method NullTerminatedEqual(bs1: Bytes, bs2: Bytes) returns (p:bool)
    requires bs1.Valid() && bs2.Valid()
    ensures p == (decode_null_terminated(bs1.data) == decode_null_terminated(bs2.data))
  {
    if bs1.Len() <= bs2.Len() {
      p := NullTerminatedEqualSmaller(bs1, bs2);
      return;
    }
    p := NullTerminatedEqualSmaller(bs2, bs1);
    return;
  }

  method NullTerminatePrefix(bs: Bytes)
    requires bs.Valid()
    modifies bs
    ensures bs.data == decode_null_terminated(old(bs.data))
  {
    var i: uint64 := 0;
    var len: uint64 := bs.Len();
    while i < len
      modifies bs
      invariant i as nat <= |bs.data|
      invariant forall k: nat | k < i as nat :: bs.data[k] != 0
      invariant decode_null_terminated(bs.data) == bs.data[..i] + decode_null_terminated(bs.data[i..])
      invariant bs.data == old(bs.data)
    {
      var b := bs.Get(i);
      if b == 0 {
        bs.Subslice(0, i);
        return;
      }
      i := i + 1;
    }
    return;
  }

  method PadPathc(bs: Bytes)
    modifies bs
    requires bs.Valid()
    requires is_pathc(bs.data)
    ensures bs.data == encode_pathc(old(bs.data))
  {
    var zeros := NewBytes(24 - bs.Len());
    bs.AppendBytes(zeros);
  }

  class MemDirents
  {
    ghost var val: Dirents
    const bs: Bytes

    ghost const Repr: set<object> := {this, bs}

    predicate Valid()
      reads Repr
    {
      && bs.data == val.enc()
      && |bs.data| == 4096
    }

    constructor(bs: Bytes, ghost dents: Dirents)
      requires bs.data == dents.enc()
      ensures Valid()
      ensures val == dents
    {
      this.bs := bs;
      this.val := dents;
      new;
      val.enc_len();
    }

    lemma data_one(k: nat)
      requires Valid()
      requires k < 128
      ensures bs.data[k*32..(k+1) * 32] == val.s[k].enc()
    {
      C.concat_homogeneous_one_list(C.seq_fmap(Dirents.encOne, val.s), k, 32);
    }

    lemma data_one_ino(k: nat)
      requires Valid()
      requires k < 128
      ensures bs.data[k*32 + 24..k*32 + 32] == IntEncoding.le_enc64(val.s[k].ino)
    {
      data_one(k);
      val.s[k].enc_app();
      assert bs.data[k*32..(k+1)*32][24..32] == bs.data[k*32 + 24..k*32 + 32];
    }

    method get_ino(k: uint64) returns (ino: Ino)
      requires Valid()
      requires k < 128
      ensures ino == val.s[k].ino
    {
      // we'll prove it's an Ino later, for now it's just a uint64
      var ino': uint64 := IntEncoding.UInt64Get(bs, k*32 + 24);
      data_one_ino(k as nat);
      IntEncoding.lemma_le_enc_dec64(val.s[k].ino);
      ino := ino';
    }

    method get_name(k: uint64) returns (name: Bytes)
      requires Valid()
      requires k < 128
      ensures fresh(name) && name.Valid() && |name.data| == 24
      ensures encode_pathc(val.s[k].name) == name.data
    {
      name := NewBytes(24);
      name.CopyFrom(bs, k*32, 24);
      data_one(k as nat);
      val.s[k].enc_app();
      assert bs.data[k*32..(k+1)*32][..24] == bs.data[k*32..k*32 + 24];
    }

    method get_dirent(k: uint64) returns (r:Option<MemDirEnt>)
      requires Valid()
      requires k < 128
      ensures r.None? ==> !val.s[k].used()
      ensures r.Some? ==>
      && val.s[k].used()
      && fresh(r.x.name)
      && r.x.Valid()
      && r.x.val() == val.s[k]
    {
      var ino := get_ino(k);
      if ino == 0 {
        return None;
      }
      var name := get_name(k);
      NullTerminatePrefix(name);
      decode_encode(val.s[k].name);
      return Some(MemDirEnt(name, ino));
    }

    method is_used(k: uint64) returns (p:bool)
      requires Valid()
      requires k < 128
      ensures p == val.s[k].used()
    {
      var ino := get_ino(k);
      p := ino != 0;
    }

    method is_name(k: uint64, needle: Bytes) returns (r:Option<Ino>)
      requires Valid()
      requires k < 128
      requires needle.Valid()
      requires is_pathc(needle.data)
      ensures r.None? ==> !(val.s[k].used() && val.s[k].name == needle.data)
      ensures r.Some? ==> val.s[k].used() && val.s[k].name == needle.data && val.s[k].ino == r.x
    {
      var ino := get_ino(k);
      if ino == 0 {
        return None;
      }
      var name := get_name(k);
      assert decode_null_terminated(name.data) == val.s[k].name by {
        decode_encode(val.s[k].name);
      }
      decode_nullterm_no_null(needle.data);
      var equal := NullTerminatedEqualSmaller(needle, name);
      if equal {
        return Some(ino);
      } else {
        return None;
      }
    }

    method findFree() returns (free_i: uint64)
      requires Valid()
      ensures free_i as nat == val.findFree()
    {
      var i: uint64 := 0;
      while i < 128
        invariant 0 <= i as nat <= 128
        invariant forall k:nat | k < i as nat :: val.s[k].used()
      {
        var p := is_used(i);
        if !p {
          C.find_first_characterization(Dirents.is_unused, val.s, i as nat);
          return i;
        }
        i := i + 1;
      }
      C.find_first_characterization(Dirents.is_unused, val.s, 128);
      return 128;
    }

    method findName(name: Bytes) returns (r: Option<(uint64, Ino)>)
      requires Valid()
      requires name.Valid() && is_pathc(name.data)
      ensures r.None? ==> name.data !in val.dir && val.findName(name.data) == 128
      ensures r.Some? ==>
      && name.data in val.dir
      && r.x.0 < 128
      && r.x.0 as nat == val.findName(name.data)
      && val.dir[name.data] == r.x.1
    {
      ghost var p: PathComp := name.data;
      var i: uint64 := 0;
      while i < 128
        invariant 0 <= i as nat <= 128
        invariant forall k:nat | k < i as nat :: !(val.s[k].used() && val.s[k].name == p)
      {
        var ino := is_name(i, name);
        if ino.Some? {
          C.find_first_characterization(preDirents.findName_pred(p), val.s, i as nat);
          assert val.findName(p) == i as nat;
          val.findName_found(p);
          return Some( (i, ino.x) );
        }
        i := i + 1;
      }
      C.find_first_characterization(preDirents.findName_pred(p), val.s, 128);
      val.findName_not_found(p);
      return None;
    }

    method usedDents() returns (dents: seq<MemDirEnt>)
      requires Valid()
      ensures forall i:nat | i < |dents| :: dents[i].Valid()
      ensures fresh(mem_dirs_repr(dents))
      ensures seq_to_dir(mem_seq_val(dents)) == val.dir
      ensures |dents| == |val.dir|
    {
      dents := [];
      var i: uint64 := 0;
      while i < 128
        invariant 0 <= i as nat <= 128
        invariant |dents| <= i as nat
        invariant forall k:nat | k < |dents| as nat :: dents[k].Valid()
        invariant fresh(mem_dirs_repr(dents))
        invariant mem_seq_val(dents) == used_dirents(val.s[..i])
      {
        assert val.s[..i+1] == val.s[..i] + [val.s[i]];
        used_dirents_app(val.s[..i], [val.s[i]]);
        var e := get_dirent(i);
        if e.Some? {
          assert val.s[i].used();
          mem_dirs_repr_app(dents, [e.x]);
          assert mem_seq_val(dents + [e.x]) == mem_seq_val(dents) + mem_seq_val([e.x]);
          //assert mem_seq_val([e.x]) == [e.x.val()];
          //assert used_dirents([val.s[i]]) == [val.s[i]];
          //calc {
          //  mem_seq_val(dents + [e.x]);
          //  mem_seq_val(dents) + mem_seq_val([e.x]);
          //  used_dirents(val.s[..i]) + [e.x.val()];
          //}
          dents := dents + [e.x];
        } else {
          assert !val.s[i].used();
          assert used_dirents(val.s[..i+1]) == used_dirents(val.s[..i]);
        }
        i := i + 1;
      }

      assert val.s[..128] == val.s;
      used_dirents_dir(val.s);
      used_dirents_size(val.s);
    }

    static method write_ent(bs: Bytes, k: uint64, ghost v: DirEnt, name: Bytes, ino: Ino)
      modifies bs
      requires k < 128
      requires |bs.data| == 4096
      requires name.data == encode_pathc(v.name) && v.ino == ino
      ensures |v.enc()| == 32
      ensures bs.data == C.splice(old(bs.data), k as nat*32, v.enc())
    {
      v.enc_len();
      v.enc_app();
      bs.CopyTo(k*32, name);
      IntEncoding.UInt64Put(ino, k*32+24, bs);
    }

    method insert_ent(k: uint64, e: MemDirEnt)
      modifies Repr, e.name
      requires Valid() ensures Valid()
      requires e.Valid()
      requires k < 128
      requires val.findName(e.val().name) >= 128
      ensures val == old(val.(s := val.s[k as nat := e.val()]))
    {
      ghost var v := e.val();
      v.enc_len();
      // modify in place to re-use space
      PadPathc(e.name);
      var padded_name := e.name;
      C.concat_homogeneous_splice_one(C.seq_fmap(Dirents.encOne, val.s), k as nat, v.enc(), 32);
      write_ent(this.bs, k, v, padded_name, e.ino);
      // needed to ensure new Dirents is Valid
      reveal val.find_name_spec();
      val := val.(s := val.s[k as nat := v]);
      assert C.seq_fmap(Dirents.encOne, val.s) == C.seq_fmap(Dirents.encOne, old(val.s)[k as nat := v]);
      // TODO: should be done, need to figure out what's missing
      assume false;
    }
  }
}