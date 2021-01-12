include "../../util/marshal.i.dfy"

// NOTE: this module, unlike the others in this development, is not intended to
// be opened
module Inode {
  import opened Machine
  import IntEncoding
  import opened Collections
  import opened ByteSlice
  import opened Marshal

  datatype Inode = Mk(sz: uint64, blks: seq<uint64>)

  function method div_roundup(x: nat, k: nat): nat
    requires k >= 1
  {
    (x + (k-1)) / k
  }

  function method NextBlock(i:Inode): uint64
  {
    i.sz/4096
  }

  predicate Valid(i:Inode)
  {
    var blks_ := i.blks;
    // only direct blocks
    && |blks_| <= 15
    // TODO: will be div_roundup
    && |blks_| == i.sz as nat/4096
    // TODO: generalize to allow non-block appends
    && i.sz % 4096 == 0
    && (forall bn | bn in blks_ :: bn != 0)
    && unique(blks_)
  }


  function inode_enc(i: Inode): seq<Encodable>
  {
    [EncUInt64(i.sz)] + seq_fmap(blkno => EncUInt64(blkno), i.blks)
  }

  lemma {:induction xs} enc_uint64_len(xs: seq<uint64>)
    ensures |seq_encode(seq_fmap(blkno => EncUInt64(blkno), xs))| == 8*|xs|
  {}

  function enc(i: Inode): (bs:seq<byte>)
    requires Valid(i)
    ensures |bs| == 128
  {
    enc_uint64_len(i.blks);
    assert |seq_encode(inode_enc(i))| == 8+8*|i.blks|;
    seq_encode(inode_enc(i)) + repeat(0 as byte, 128-(8+8*|i.blks|))
  }

  const zero: Inode := Mk(0, []);

  lemma zero_valid()
    ensures Valid(zero)
  {}

  lemma zero_encoding()
    ensures Valid(zero)
    ensures repeat(0 as byte, 128) == enc(zero)
  {
    zero_valid();
    //assert inode_enc(zero) == [EncUInt64(0)];
    //assert repeat(0 as byte, 8) == [0,0,0,0,0,0,0,0];
    repeat_split(0 as byte, 128, 8, 128-8);
    IntEncoding.lemma_enc_0();
  }

  method encode_ino(i: Inode) returns (bs:Bytes)
    modifies {}
    requires Valid(i)
    ensures fresh(bs)
    ensures bs.data == enc(i)
    ensures |bs.data| == 128
  {
    var e := new Encoder(128);
    e.PutInt(i.sz);
    var num_blocks := i.sz/4096;
    assert num_blocks as nat == |i.blks|;
    var k: uint64 := 0;
    while k < num_blocks
      modifies e.Repr
      invariant e.Valid()
      invariant 0 <= k <= num_blocks
      invariant e.bytes_left() == 128 - ((k as nat+1)*8)
      invariant e.enc ==
      [EncUInt64(i.sz)] +
      seq_fmap(blkno => EncUInt64(blkno), i.blks[..k])
    {
      e.PutInt(i.blks[k as nat]);
      k := k + 1;
    }
    assert i.blks[..|i.blks|] == i.blks;
    assert e.enc == inode_enc(i);
    bs := e.Finish();
  }

  method decode_ino(bs: Bytes, ghost i: Inode) returns (i': Inode)
    modifies {}
    requires bs.Valid()
    requires Valid(i)
    requires bs.data == enc(i)
    ensures i' == i
  {
    var dec := new Decoder();
    dec.Init(bs, inode_enc(i));
    var sz := dec.GetInt(i.sz);
    var num_blks: uint64 := sz/4096;
    assert num_blks as nat == |i.blks|;
    assert dec.enc == seq_fmap(blkno => EncUInt64(blkno), i.blks);

    var blks: seq<uint64> := [];

    var k: uint64 := 0;
    while k < num_blks
      modifies dec
      invariant dec.Valid()
      invariant Valid(i)
      invariant 0 <= k <= num_blks
      invariant blks == i.blks[..k]
      invariant dec.enc == seq_fmap(blkno => EncUInt64(blkno), i.blks[k..])
    {
      var blk := dec.GetInt(i.blks[k as nat]);
      blks := blks + [blk];
      k := k + 1;
    }
    return Mk(sz, blks);
  }
}