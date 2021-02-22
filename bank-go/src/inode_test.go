package compile_test

import (
	"testing"

	inode "Inode_Compile"
	_dafny "dafny"

	bytes "github.com/mit-pdos/dafny-jrnl/src/dafny_go/bytes"
	"github.com/stretchr/testify/assert"
	"github.com/tchajed/marshal"
)

func u64_slice_to_seq(xs []uint64) _dafny.Seq {
	xs_i := make([]interface{}, len(xs))
	for i, x := range xs {
		xs_i[i] = x
	}
	return _dafny.SeqOf(xs_i...)
}

func MkInode(sz uint64, blks []uint64) inode.PreInode {
	blk_seq := u64_slice_to_seq(blks)
	ty := inode.Companion_InodeType_.Create_FileType_()
	meta := inode.Companion_Meta_.Create_Meta_(sz, ty)
	return inode.Companion_PreInode_.Create_Mk_(meta, blk_seq)
}

func EncodeIno(i inode.PreInode) *bytes.Bytes {
	return inode.Companion_Default___.Encode__ino(i)
}

func DecodeIno(bs *bytes.Bytes) inode.PreInode {
	return inode.Companion_Default___.Decode__ino(bs)
}

func decodeIno(bs []byte) (sz uint64, blks []uint64) {
	dec := marshal.NewDec(bs)
	sz = dec.GetInt()
	// type
	_ = dec.GetInt()
	blks = make([]uint64, 14)
	for i := 0; i < 14; i++ {
		blks[i] = dec.GetInt()
	}
	return
}

func ManualDecodeIno(bs *bytes.Bytes) inode.PreInode {
	sz, blks := decodeIno(bs.Data)
	return MkInode(sz, blks)
}

var i inode.PreInode = MkInode(5000, []uint64{1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14})

func BenchmarkInodeDecode(b *testing.B) {
	bs := EncodeIno(i)
	b.ResetTimer()
	for k := 0; k < b.N; k++ {
		DecodeIno(bs)
	}
}

func BenchmarkInodeDecodeManual(b *testing.B) {
	bs := EncodeIno(i)
	b.ResetTimer()
	for k := 0; k < b.N; k++ {
		ManualDecodeIno(bs)
	}
}

func TestDecodeIno(t *testing.T) {
	bs := EncodeIno(i).Data
	sz, blks := decodeIno(bs)
	assert.Equal(t, uint64(5000), sz, "size incorrect")
	assert.Equal(t, 14, len(blks), "len(blks) incorrect")
	assert.Equal(t, uint64(3), blks[2], "blks values incorrect")
}

func Benchmark_DecodeIno(b *testing.B) {
	bs := EncodeIno(i).Data
	b.ResetTimer()
	for k := 0; k < b.N; k++ {
		sz, blks := decodeIno(bs)
		if sz != 5000 || len(blks) != 14 {
			b.FailNow()
		}
	}
}
