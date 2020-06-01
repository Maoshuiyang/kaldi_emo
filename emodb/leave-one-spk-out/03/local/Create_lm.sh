#!/bin/bash
. ./path.sh || exit 1;
. cmd.sh

# Create the phone n-gram LM
lmdir=data/local/lm_dir
lexicon=data/local/dict/lexicon.txt
mkdir $lmdir

cut -d' ' -f2- data/local/train_text | sed -e 's:^:<s> :' -e 's:$: </s>:' > $lmdir/lm_train_text

build-lm.sh -i $lmdir/lm_train_text -n 3 -o $lmdir/lm_tg.ilm.gz

compile-lm $lmdir/lm_tg.ilm.gz -t=yes /dev/stdout | grep -v unk | gzip -c > $lmdir/lm_tg.arpa.gz

#Create the corresponding FST for LM model
gunzip -c $lmdir/lm_tg.arpa.gz | arpa2fst --disambig-symbol=#0 --read-symbol-table=data/lang/words.txt - data/lang/G.fst
fstisstochastic data/lang/G.fst

# Everything below is only for diagnostic.
 # Checking that G has no cycles with empty words on them (e.g. <s>, </s>);
 # this might cause determinization failure of CLG.
 # #0 is treated as an empty word.
tmpdir=data/local/lm_tmp

mkdir -p $tmpdir/g
awk '{if(NF==1){ printf("0 0 %s %s\n", $1,$1); }} END{print "0 0 #0 #0"; print "0";}' \
    < "$lexicon"  >$tmpdir/g/select_empty.fst.txt
  fstcompile --isymbols=data/lang/words.txt --osymbols=data/lang/words.txt $tmpdir/g/select_empty.fst.txt | \
   fstarcsort --sort_type=olabel | fstcompose - data/lang/G.fst > $tmpdir/g/empty_words.fst
  fstinfo $tmpdir/g/empty_words.fst | grep cyclic | grep -w 'y' &&
echo "Language model has cycles with empty words" && exit 1
rm -r $tmpdir/g

utils/validate_lang.pl data/lang || exit 1

echo "Succeeded in formatting LM.fst."
rm -r $tmpdir
