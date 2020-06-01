		#!/bin/bash

. ./cmd.sh ## You'll want to change cmd.sh to something that will work on your system.
           ## This relates to the queue.
. ./path.sh

stage=0
sil_prob=0
totgauss=120 #500
no_cyclic=

dict_data_dir="data/local/dict"
lang_data_dir="data/lang"

train_data_dir="data/train";
test_data_dir="data/test";
mfcc_conf="conf/mfcc.conf";
exp_dir="exp-all-steps";

# Acoustic model parameters
numLeavesTri1=250  #2500, 250 
numGaussTri1=150 #15000, 150
numLeavesMLLT=250  #2500, 250
numGaussMLLT=150 #15000, 150
numLeavesSAT=250 #2500, 250
numGaussSAT=150  #15000, 150
numGaussUBM=40 #400, 40
numLeavesSGMM=250 #7000, 70
numGaussSGMM=150 #9000, 90 

njtrain=1
njdecod=1

# echo ============================================================================
# echo "                Data & Lexicon & Language Preparation                     "
# echo ============================================================================

# utils/prepare_lang.sh --sil_prob $sil_prob --position-dependent-phones false --num-nonsil-states 5 \
# $dict_data_dir "<SIL>" $lang_data_dir/tmp $lang_data_dir


# echo ============================================================================
# echo "         MFCC Feature Extration & CMVN for Training and Test set          "
# echo ============================================================================

# for x in $train_data_dir $test_data_dir; do
#  # steps/make_mfcc.sh --mfcc-config $mfcc_conf --nj $njob $x $x/make_mfcc $x/mfcc
#  # steps/compute_cmvn_stats.sh $x $x/make_mfcc $x/mfcc
#  steps/make_mfcc_pitch.sh --mfcc-config conf/mfcc.conf --pitch-config conf/pitch.conf \
#  --nj $njtrain $x $x/make_mfcc $x/mfcc
#  steps/compute_cmvn_stats.sh $x $x/make_mfcc $x/mfcc
#  utils/fix_data_dir.sh $x
# done


# echo ============================================================================
# echo "                     MonoPhone Training & Decoding                        "
# echo ============================================================================

# steps/train_mono.sh \
# --nj $njtrain --cmd run.pl --totgauss $totgauss \
# $train_data_dir $lang_data_dir $exp_dir/mono;

# utils/mkgraph.sh data/lang $exp_dir/mono $exp_dir/mono/graph;

# steps/decode.sh --nj $njdecod --cmd run.pl  $exp_dir/mono/graph $test_data_dir $exp_dir/mono/decode_test;


# echo ============================================================================
# echo "           tri1 : Deltas + Delta-Deltas Training & Decoding               "
# echo ============================================================================

# steps/align_si.sh --boost-silence 1.25 --nj 1 --cmd "$train_cmd" \
# data/train data/lang $exp_dir/mono $exp_dir/mono_ali

# # Train tri1, which is deltas + delta-deltas, on train data.
# steps/train_deltas.sh --cmd "$train_cmd" \
# $numLeavesTri1 $numGaussTri1 data/train data/lang $exp_dir/mono_ali $exp_dir/tri1

# utils/mkgraph.sh data/lang $exp_dir/tri1 $exp_dir/tri1/graph

# steps/decode.sh --nj $njdecod --cmd "$decode_cmd" \
# $exp_dir/tri1/graph data/test $exp_dir/tri1/decode_test


# # echo ============================================================================
# # echo "                 tri2 : LDA + MLLT Training & Decoding                    "
# # echo ============================================================================

# # steps/align_si.sh --nj 1 --cmd "$train_cmd" \
# #   data/train data/lang $exp_dir/tri1 $exp_dir/tri1_ali

# # steps/train_lda_mllt.sh --cmd "$train_cmd" \
# #  --splice-opts "--left-context=3 --right-context=3" \
# #  $numLeavesMLLT $numGaussMLLT data/train data/lang $exp_dir/tri1_ali $exp_dir/tri2

# # utils/mkgraph.sh data/lang $exp_dir/tri2 $exp_dir/tri2/graph

# # steps/decode.sh --nj $njdecod --cmd "$decode_cmd" \
# #  $exp_dir/tri2/graph data/test $exp_dir/tri2/decode_test


# echo ============================================================================
# echo "              tri3 : LDA + MLLT + SAT Training & Decoding                 "
# echo ============================================================================

# # Align tri2 system with train data.
# steps/align_si.sh --nj 1 --cmd "$train_cmd" \
# --use-graphs true data/train data/lang $exp_dir/tri1 $exp_dir/tri1_ali

# # From tri2 system, train tri3 which is LDA + MLLT + SAT.
# steps/train_sat.sh --cmd "$train_cmd" \
# $numLeavesSAT $numGaussSAT data/train data/lang $exp_dir/tri1_ali $exp_dir/tri3

# utils/mkgraph.sh data/lang $exp_dir/tri3 $exp_dir/tri3/graph

# steps/decode_fmllr.sh --nj $njdecod --cmd "$decode_cmd" \
# $exp_dir/tri3/graph data/test $exp_dir/tri3/decode_test


# echo ============================================================================
# echo "                        SGMM2 Training & Decoding                         "
# echo ============================================================================

# steps/align_fmllr.sh --nj 1 --cmd "$train_cmd" \
# data/train data/lang $exp_dir/tri3 $exp_dir/tri3_ali

# # exit 0 # From this point you can run Karel's DNN : local/nnet/run_dnn.sh

# steps/train_ubm.sh --cmd run.pl \
# $numGaussUBM data/train data/lang $exp_dir/tri3_ali $exp_dir/ubm4

# steps/train_sgmm2.sh --cmd run.pl $numLeavesSGMM $numGaussSGMM \
# data/train data/lang $exp_dir/tri3_ali $exp_dir/ubm4/final.ubm $exp_dir/sgmm2_4

# utils/mkgraph.sh data/lang $exp_dir/sgmm2_4 $exp_dir/sgmm2_4/graph

# steps/decode_sgmm2.sh --nj $njdecod --cmd run.pl \
# --transform-dir $exp_dir/tri3/decode_test $exp_dir/sgmm2_4/graph data/test \
# $exp_dir/sgmm2_4/decode_test


echo ============================================================================
echo "                    MMI + SGMM2 Training & Decoding                       "
echo ============================================================================

steps/align_sgmm2.sh --nj 1 --cmd run.pl \
--transform-dir $exp_dir/tri3_ali --use-graphs true --use-gselect true \
data/train data/lang $exp_dir/sgmm2_4 $exp_dir/sgmm2_4_ali

steps/make_denlats_sgmm2.sh --nj 1 --sub-split 1 \
--acwt 0.2 --lattice-beam 10.0 --beam 18.0 \
--cmd run.pl --transform-dir $exp_dir/tri3_ali \
data/train data/lang $exp_dir/sgmm2_4_ali $exp_dir/sgmm2_4_denlats

steps/train_mmi_sgmm2.sh --acwt 0.2 --cmd run.pl \
--transform-dir $exp_dir/tri3_ali --boost 0.1 --drop-frames true \
data/train data/lang $exp_dir/sgmm2_4_ali $exp_dir/sgmm2_4_denlats $exp_dir/sgmm2_4_mmi_b0.1

for iter in 1 2 3 4; do
  steps/decode_sgmm2_rescore.sh --cmd run.pl --iter $iter \
   --transform-dir $exp_dir/tri3/decode_test data/lang data/test \
   $exp_dir/sgmm2_4/decode_test $exp_dir/sgmm2_4_mmi_b0.1/decode_test_it$iter
done


# echo ============================================================================
# echo "                    DNN Hybrid Training & Decoding                        "
# echo ============================================================================

# # DNN hybrid system training parameters
# dnn_mem_reqs="--mem 1G"
# dnn_extra_opts="--num_epochs 20 --num-epochs-extra 10 --add-layers-period 1 --shrink-interval 3"

# steps/nnet2/train_tanh.sh --mix-up 5000 --initial-learning-rate 0.015 \
#  --final-learning-rate 0.002 --num-hidden-layers 2  --hidden_layer_dim 128 \
#  --num-jobs-nnet $njtrain --cmd run.pl "${dnn_train_extra_opts[@]}" \
#  data/train data/lang $exp_dir/sgmm2_4_ali $exp_dir/tri4_nnet

# ### [ ! -d $exp_dir/tri4_nnet/decode_test ] && mkdir -p $exp_dir/tri4_nnet/decode_test
# ### steps/nnet2/decode.sh --cmd "$decode_cmd" --nj $njdecod "${decode_extra_opts[@]}" \
# ###   --transform-dir $exp_dir/tri3/decode_test $exp_dir/tri3/graph data/test \
# ###   $exp_dir/tri4_nnet/decode_test | tee $exp_dir/tri4_nnet/decode_test/decode.log

# [ ! -d $exp_dir/tri4_nnet/decode_test ] && mkdir -p $exp_dir/tri4_nnet/decode_test
# steps/nnet2/decode.sh --cmd "$decode_cmd" --nj $njdecod "${decode_extra_opts[@]}" \
#  $exp_dir/tri3/graph data/test \
#  $exp_dir/tri4_nnet/decode_test | tee $exp_dir/tri4_nnet/decode_test/decode.log

# steps/nnet2/align.sh --nj 1 --cmd run.pl \
# data/train data/lang $exp_dir/tri4_nnet $exp_dir/tri4_ali

# steps/nnet2/train_tanh.sh --mix-up 5000 --initial-learning-rate 0.015 \
#  --final-learning-rate 0.002 --num-hidden-layers 2  \
#  --num-jobs-nnet $njtrain --cmd run.pl "${dnn_train_extra_opts[@]}" \
#  data/train data/lang $exp_dir/tri4_ali $exp_dir/tri4b_nnet

# [ ! -d $exp_dir/tri4b_nnet/decode_test ] && mkdir -p $exp_dir/tri4b_nnet/decode_test
# steps/nnet2/decode.sh --cmd "$decode_cmd" --nj $njdecod "${decode_extra_opts[@]}" \
#  $exp_dir/tri3/graph data/test \
#  $exp_dir/tri4b_nnet/decode_test | tee $exp_dir/tri4b_nnet/decode_test/decode.log

# steps/nnet2/align.sh --nj 1 --cmd run.pl \
# data/train data/lang $exp_dir/tri4b_nnet $exp_dir/tri4b_ali

# steps/nnet2/train_tanh.sh --mix-up 5000 --initial-learning-rate 0.015 \
#  --final-learning-rate 0.002 --num-hidden-layers 2  \
#  --num-jobs-nnet $njtrain --cmd run.pl "${dnn_train_extra_opts[@]}" \
#  data/train data/lang $exp_dir/tri4b_ali $exp_dir/tri4c_nnet

# [ ! -d $exp_dir/tri4c_nnet/decode_test ] && mkdir -p $exp_dir/tri4c_nnet/decode_test
# steps/nnet2/decode.sh --cmd "$decode_cmd" --nj $njdecod "${decode_extra_opts[@]}" \
#  $exp_dir/tri3/graph data/test \
#  $exp_dir/tri4c_nnet/decode_test | tee $exp_dir/tri4c_nnet/decode_test/decode.log

# steps/nnet2/align.sh --nj 1 --cmd run.pl \
#  data/train data/lang $exp_dir/tri4c_nnet $exp_dir/tri4c_ali
 
# steps/nnet2/train_tanh.sh --mix-up 5000 --initial-learning-rate 0.015 \
#   --final-learning-rate 0.002 --num-hidden-layers 2  \
#   --num-jobs-nnet $njtrain --cmd run.pl "${dnn_train_extra_opts[@]}" \
#   data/train data/lang $exp_dir/tri4c_ali $exp_dir/tri4d_nnet
 
# [ ! -d $exp_dir/tri4d_nnet/decode_test ] && mkdir -p $exp_dir/tri4d_nnet/decode_test
# steps/nnet2/decode.sh --cmd "$decode_cmd" --nj $njdecod "${decode_extra_opts[@]}" \
#   $exp_dir/tri3/graph data/test \
#   $exp_dir/tri4d_nnet/decode_test | tee $exp_dir/tri4d_nnet/decode_test/decode.log



#echo ============================================================================
#echo "                    System Combination (DNN+SGMM)                         "
#echo ============================================================================
#
#for iter in 1 2 3 4; do
#  local/score_combine.sh --cmd run.pl \
#   data/test data/lang $exp_dir/tri4_nnet/decode_test \
#   $exp_dir/sgmm2_4_mmi_b0.1/decode_test_it$iter $exp_dir/combine_2/decode_test_it$iter
#done
#
# echo ============================================================================
# echo "               DNN Hybrid Training & Decoding (Karel's recipe)            "
# echo ============================================================================

# local/nnet/run_dnn.sh
# #local/nnet/run_autoencoder.sh : an example, not used to build any system,

# echo ============================================================================
# echo "                    Getting Results [see RESULTS file]                    "
# echo ============================================================================

# #bash RESULTS dev
# bash RESULTS test

echo ============================================================================
echo "Finished successfully on" `date`
echo ============================================================================

exit 0
