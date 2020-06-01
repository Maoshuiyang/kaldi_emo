#!/bin/bash

# this is our online-nnet2 build.  it's a "multi-splice" system (i.e. we have
# splicing at various layers), with p-norm nonlinearities.  We use the "accel2"
# script which uses between 2 and 14 GPUs depending how far through training it
# is.  You can safely reduce the --num-jobs-final to however many GPUs you have
# on your system.

# For joint training with RM, this script is run using the following command line,
# and note that the --stage 8 option is only needed in case you already ran the
# earlier stages.
# local/online/run_nnet2.sh --stage 8 --dir exp/nnet2_online/nnet_ms_a_partial --exit-train-stage 15

stage=0
train_stage=-10
use_gpu=true
dir=exp/nnet2_online/nnet_ms_a
exit_train_stage=-100
. ./cmd.sh
. ./path.sh
. ./utils/parse_options.sh

if $use_gpu; then
  if ! cuda-compiled; then
    cat <<EOF && exit 1 
This script is intended to be used with GPUs but you have not compiled Kaldi with CUDA 
If you want to use GPUs (and have them), go to src/, and configure and make on a machine
where "nvcc" is installed.  Otherwise, call this script with --use-gpu false
EOF
  fi
  parallel_opts="--gpu 1"
  num_threads=1
  minibatch_size=512
  # the _a is in case I want to change the parameters.
else
  num_threads=16
  minibatch_size=128
  parallel_opts="--num-threads $num_threads"
fi

#local/online/run_nnet2_common.sh --stage $stage || exit 1;

if [ $stage -le 7 ]; then
  # last splicing was instead: layer3/-4:2" 
  steps/nnet2/train_multisplice_accel2.sh --stage $train_stage \
    --exit-stage $exit_train_stage \
    --num-epochs 8 --num-jobs-initial 2 --num-jobs-final 4 \
    --num-hidden-layers 4 \
    --splice-indexes "layer0/-1:0:1 layer1/-2:1 layer2/-4:2" \
    --feat-type raw \
    --online-ivector-dir exp/nnet2_online/ivectors_train_online \
    --cmvn-opts "--norm-means=false --norm-vars=false" \
    --num-threads "$num_threads" \
    --minibatch-size "$minibatch_size" \
    --parallel-opts "$parallel_opts" \
    --io-opts "--max-jobs-run 12" \
    --initial-effective-lrate 0.005 --final-effective-lrate 0.0005 \
    --cmd "$decode_cmd" \
    --pnorm-input-dim 2000 \
    --pnorm-output-dim 250 \
    --mix-up 12000 \
    data/train data/lang exp/nnet2_online/tri3b_ali $dir  || exit 1;
fi

if [ $stage -le 8 ]; then
  # If this setup used PLP features, we'd have to give the option --feature-type plp
  # to the script below.
  iter_opt=
  [ $exit_train_stage -gt 0 ] && iter_opt="--iter $exit_train_stage"
  steps/online/nnet2/prepare_online_decoding.sh $iter_opt --mfcc-config conf/mfcc.conf \
    data/lang exp/nnet2_online/extractor "$dir" ${dir}_online || exit 1;
fi

if [ $exit_train_stage -gt 0 ]; then
  echo "$0: not testing since you only ran partial training (presumably in preparation"
  echo " for multilingual training"
  exit 0;
fi

#if [ $stage -le 9 ]; then
  # this does offline decoding that should give the same results as the real
  # online decoding.
 # graph_dir=exp/tri3b/graph
  # use already-built graphs.
#  steps/nnet2/decode.sh --nj 8 --cmd "$decode_cmd" \
#      --online-ivector-dir exp/nnet2_online/ivectors_test_online \
#         $graph_dir data/test $dir/decode_test_online || exit 1;
#fi

#if [ $stage -le 10 ]; then
  # do the actual online decoding with iVectors, carrying info forward from 
  # previous utterances of the same speaker.
 #   graph_dir=exp/tri3b/graph
 #   steps/online/nnet2/decode.sh --cmd "$decode_cmd" --nj 8 \
 #      "$graph_dir" data/test ${dir}_online/decode_test_online || exit 1;
#fi

if [ $stage -le 11 ]; then
  # this version of the decoding treats each utterance separately
  # without carrying forward speaker information.
  graph_dir=exp/tri3b/graph
  steps/online/nnet2/decode.sh --cmd "$decode_cmd" --nj 8 \
      --per-utt true \
      "$graph_dir" data/test ${dir}_online/decode_test_online_utt || exit 1;
fi
<< comment
if [ $stage -le 12 ]; then
  # this version of the decoding treats each utterance separately
  # without carrying forward speaker information.  By setting --online false we
  # let it estimate the iVector from the whole utterance; it's then given to all
  # frames of the utterance.  So it's not really online.
  graph_dir=exp/tri3b/graph
  steps/online/nnet2/decode.sh --cmd "$decode_cmd" --nj 8 \
      --per-utt true --online false \
      "$graph_dir" data/test ${dir}_online/decode_test_online_utt_offline || exit 1;
fi

if [ $stage -le 13 ]; then
  # this does offline decoding, as stage 10, except we estimate the iVectors per
  # speaker, excluding silence (based on alignments from a GMM decoding), with a
  # different script.  This is just to demonstrate that script.
  # the --sub-speaker-frames is optional; if provided, it will divide each speaker
  # up into "sub-speakers" of at least that many frames... can be useful if
  # acoustic conditions drift over time within the speaker's data.
  rm exp/nnet2_online/.error 2>/dev/null
  steps/online/nnet2/extract_ivectors.sh --cmd "$train_cmd" --nj 8 \
      --sub-speaker-frames 1500 \
      data/test data/lang exp/nnet2_online/extractor \
      exp/tri3b/decode_test exp/nnet2_online/ivectors_spk_test || touch exp/nnet2_online/.error
  wait
  [ -f exp/nnet2_online/.error ] && echo "$0: Error getting iVectors" && exit 1;

  graph_dir=exp/tri3b/graph
  # use already-built graphs.
  steps/nnet2/decode.sh --nj 8 --cmd "$decode_cmd" \
     --online-ivector-dir exp/nnet2_online/ivectors_spk_test \
     $graph_dir data/test $dir/decode_test_spk || touch exp/nnet2_online/.error
  wait
  [ -f exp/nnet2_online/.error ] && echo "$0: Error decoding" && exit 1;
fi
comment

exit 0;
