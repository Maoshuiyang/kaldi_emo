#!/bin/bash
# This script refers to the wsj ,and ingores those operations on dataset, 
# e.g. utils/copy_data_dir.sh, utils/subset_data_dir.sh .(12/01/2017)

stage=1
nj=10
. ./cmd.sh
. ./path.sh
. ./utils/parse_options.sh

if [ $stage -le 1 ]; then
  # We need to build a small system just because we need the LDA+MLLT transform
  # to train the diag-UBM on top of.  We align the training data for this purpose.

  steps/align_fmllr.sh --nj $nj --cmd "$train_cmd" \
    data/train data/lang exp/tri3b exp/nnet2_online/tri3b_ali || exit 1;
fi

if [ $stage -le 2 ]; then
  # Train a small system just for its LDA+MLLT transform.  We use --num-iters 13
  # because after we get the transform (12th iter is the last), any further
  # training is pointless.
  steps/train_lda_mllt.sh --cmd "$train_cmd" --num-iters 13 \
    --realign-iters "" \
    --splice-opts "--left-context=3 --right-context=3" \
    5000 10000 data/train data/lang \
    exp/nnet2_online/tri3b_ali exp/nnet2_online/tri4b || exit 1;
fi

if [ $stage -le 3 ]; then
  mkdir -p exp/nnet2_online
  steps/online/nnet2/train_diag_ubm.sh --cmd "$train_cmd" --nj $nj \
     --num-frames 400000 data/train 256 exp/nnet2_online/tri4b exp/nnet2_online/diag_ubm || exit 1;
fi

if [ $stage -le 4 ]; then
  # even though $nj is just 10, each job uses multiple processes and threads.
  steps/online/nnet2/train_ivector_extractor.sh --cmd "$train_cmd" --nj 10 \
    data/train exp/nnet2_online/diag_ubm exp/nnet2_online/extractor || exit 1;
fi

if [ $stage -le 5 ]; then
  # We extract iVectors on all the train data, which will be what we
  # train the system on.

  # having a larger number of speakers is helpful for generalization, and to
  # handle per-utterance decoding well (iVector starts at zero).
  steps/online/nnet2/copy_data_dir.sh --utts-per-spk-max 2 data/train \
    data/train_max2 || exit 1;

  steps/online/nnet2/extract_ivectors_online.sh --cmd "$train_cmd" --nj $nj \
    data/train_max2 exp/nnet2_online/extractor exp/nnet2_online/ivectors_train_online || exit 1;
fi
<< comment
if [ $stage -le 6 ]; then
  rm exp/nnet2_online/.error 2>/dev/null
  for data in test; do
    steps/online/nnet2/extract_ivectors_online.sh --cmd "$train_cmd" --nj 4 \
      data/${data} exp/nnet2_online/extractor exp/nnet2_online/ivectors_${data}_online || touch exp/nnet2_online/.error &
  done
  wait
  [ -f exp/nnet2_online/.error ] && echo "$0: error extracting iVectors." && exit 1;
fi
comment
exit 0;
