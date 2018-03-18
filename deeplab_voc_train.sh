#!/usr/bin/env bash


# try to repeat the auther's result
# train from the pre-trained model only use ImageNet
# I only have a samll GPU, so it is hard to repeat the author's,
# but I hope have close result and watch the training process
# modified from "tensorflow/models/research/deeplab/local_test.sh"

#set GPU on Cryo06
export CUDA_VISIBLE_DEVICES=1

tf_research_dir="/home/hlc/codes/PycharmProjects/tensorflow/models/research"
WORK_DIR="/home/hlc/Data/2018_IEEE_GRSS_Data_Fusion/deeplabv4_1"
deeplab_dir=${tf_research_dir}/deeplab

# go to work dir
cd $WORK_DIR

#
# This script is used to run local test on PASCAL VOC 2012. Users could also
# modify from this script for their use case.
#
# Usage:
#   # From the tensorflow/models/research/deeplab directory.
#   sh ./local_test.sh
#
#

# Exit immediately if a command exits with a non-zero status.
set -e

# Move one-level up to tensorflow/models/research directory.
#cd ..

# Update PYTHONPATH.
export PYTHONPATH=$PYTHONPATH:${tf_research_dir}
export PYTHONPATH=$PYTHONPATH:${tf_research_dir}/slim


# Set up the working environment.
#CURRENT_DIR=$(pwd)
#WORK_DIR="${CURRENT_DIR}/deeplab"

# Run model_test first to make sure the PYTHONPATH is correctly set.
#python "${WORK_DIR}"/model_test.py -v

# Go to datasets folder and download PASCAL VOC 2012 segmentation dataset.
DATASET_DIR="datasets"
mkdir -p ${DATASET_DIR}
cd ${DATASET_DIR}
cp ${deeplab_dir}/datasets/remove_gt_colormap.py .
cp ${deeplab_dir}/datasets/build_voc2012_data.py .
cp ${deeplab_dir}/datasets/build_data.py .
cp ${deeplab_dir}/datasets/download_and_convert_voc2012.sh .
#bash download_and_convert_voc2012.sh

# Go back to original directory.
cd "${WORK_DIR}"

# Set up the working directories.
PASCAL_FOLDER="pascal_voc_seg"
EXP_FOLDER="exp/train_on_trainval_set"

INIT_FOLDER="${WORK_DIR}/${PASCAL_FOLDER}/${EXP_FOLDER}/init_models"
TRAIN_LOGDIR="${WORK_DIR}/${PASCAL_FOLDER}/${EXP_FOLDER}/train"
EVAL_LOGDIR="${WORK_DIR}/${PASCAL_FOLDER}/${EXP_FOLDER}/eval"
VIS_LOGDIR="${WORK_DIR}/${PASCAL_FOLDER}/${EXP_FOLDER}/vis"
EXPORT_DIR="${WORK_DIR}/${PASCAL_FOLDER}/${EXP_FOLDER}/export"

mkdir -p "${INIT_FOLDER}"
mkdir -p "${TRAIN_LOGDIR}"
mkdir -p "${EVAL_LOGDIR}"
mkdir -p "${VIS_LOGDIR}"
mkdir -p "${EXPORT_DIR}"

# Copy locally the trained checkpoint as the initial checkpoint.
TF_INIT_ROOT="http://download.tensorflow.org/models"
TF_INIT_CKPT="deeplabv3_xception_2018_01_04.tar.gz"     #xception

cd "${INIT_FOLDER}"
wget -nd -c "${TF_INIT_ROOT}/${TF_INIT_CKPT}"
tar -xf "${TF_INIT_CKPT}"
#cd "${CURRENT_DIR}"
cd "${WORK_DIR}"

PASCAL_DATASET="${WORK_DIR}/${DATASET_DIR}/${PASCAL_FOLDER}/tfrecord"


# Train 10 iterations.
NUM_ITERATIONS=30000
python "${deeplab_dir}"/train.py \
  --logtostderr \
  --train_split="trainval" \
  --model_variant="xception_65" \
  --atrous_rates=6 \
  --atrous_rates=12 \
  --atrous_rates=18 \
  --output_stride=16 \
  --decoder_output_stride=4 \
  --train_crop_size=513 \
  --train_crop_size=513 \
  --train_batch_size=4 \
  --training_number_of_steps="${NUM_ITERATIONS}" \
  --fine_tune_batch_norm=true \
  --tf_initial_checkpoint="${INIT_FOLDER}/xception/model.ckpt" \
  --train_logdir="${TRAIN_LOGDIR}" \
  --dataset_dir="${PASCAL_DATASET}"

# Run evaluation. This performs eval over the full val split (1449 images) and
# will take a while.
# Using the provided checkpoint, one should expect mIOU=82.20%. (can read this on TensorBoard)
python "${deeplab_dir}"/eval.py \
  --logtostderr \
  --eval_split="val" \
  --model_variant="xception_65" \
  --atrous_rates=6 \
  --atrous_rates=12 \
  --atrous_rates=18 \
  --output_stride=16 \
  --decoder_output_stride=4 \
  --eval_crop_size=513 \
  --eval_crop_size=513 \
  --checkpoint_dir="${TRAIN_LOGDIR}" \
  --eval_logdir="${EVAL_LOGDIR}" \
  --dataset_dir="${PASCAL_DATASET}" \
  --max_number_of_evaluations=1

# Visualize the results.
python "${deeplab_dir}"/vis.py \
  --logtostderr \
  --vis_split="val" \
  --model_variant="xception_65" \
  --atrous_rates=6 \
  --atrous_rates=12 \
  --atrous_rates=18 \
  --output_stride=16 \
  --decoder_output_stride=4 \
  --vis_crop_size=513 \
  --vis_crop_size=513 \
  --checkpoint_dir="${TRAIN_LOGDIR}" \
  --vis_logdir="${VIS_LOGDIR}" \
  --dataset_dir="${PASCAL_DATASET}" \
  --max_number_of_iterations=1

# Export the trained checkpoint.
CKPT_PATH="${TRAIN_LOGDIR}/model.ckpt-${NUM_ITERATIONS}"
EXPORT_PATH="${EXPORT_DIR}/frozen_inference_graph.pb"

python "${deeplab_dir}"/export_model.py \
  --logtostderr \
  --checkpoint_path="${CKPT_PATH}" \
  --export_path="${EXPORT_PATH}" \
  --model_variant="xception_65" \
  --atrous_rates=6 \
  --atrous_rates=12 \
  --atrous_rates=18 \
  --output_stride=16 \
  --decoder_output_stride=4 \
  --num_classes=21 \
  --crop_size=513 \
  --crop_size=513 \
  --inference_scales=1.0

# Run inference with the exported checkpoint.
# Please refer to the provided deeplab_demo.ipynb for an example.
