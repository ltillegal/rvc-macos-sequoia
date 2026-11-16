#!/bin/sh
#
# Downloads the pretrained models RVC needs.
#
#   ./tools/dlmodels.sh          download whatever is missing
#   ./tools/dlmodels.sh --check  list the missing files, download nothing
#
# --check exits 0 when every required file is present and 1 otherwise, so the
# launcher can re-run the download after a partial failure.
#

CHECK_ONLY=0
[ "${1:-}" = "--check" ] && CHECK_ONLY=1
MISSING=0

printf "working dir is %s\n" "$PWD"

if [ "$CHECK_ONLY" != "1" ]; then
    echo "downloading requirement aria2 check."
    if command -v aria2c > /dev/null 2>&1
    then
        echo "aria2 command found"
    else
        echo "failed. please install aria2"
        exit 1
    fi
fi

echo "dir check start."

check_dir() {
    [ -d "$1" ] && printf "dir %s checked\n" "$1" || \
    printf "failed. generating dir %s\n" "$1" && mkdir -p "$1"
}

if [ "$CHECK_ONLY" != "1" ]; then
    check_dir "./assets/pretrained"
    check_dir "./assets/pretrained_v2"
    check_dir "./assets/uvr5_weights"
    check_dir "./assets/uvr5_weights/onnx_dereverb_By_FoxJoy"
fi

echo "dir check finished."

echo "required files check start."
check_file_pretrained() {
  printf "checking %s\n" "$2"
  if [ -f "./assets/""$1""/""$2""" ]; then
      printf "%s in ./assets/%s checked.\n" "$2" "$1" 
  else
      MISSING=$((MISSING + 1))
      printf "missing: ./assets/%s/%s\n" "$1" "$2"
      [ "$CHECK_ONLY" = "1" ] && return 0
      echo failed. starting download from huggingface.
      if command -v aria2c > /dev/null 2>&1; then
          aria2c --console-log-level=error -c -x 16 -s 16 -k 1M https://huggingface.co/lj1995/VoiceConversionWebUI/resolve/main/"$1"/"$2" -d ./assets/"$1" -o "$2"
          [ -f "./assets/""$1""/""$2""" ] && echo "download successful." || { echo "please try again!" && exit 1; }
      else
          echo "aria2c command not found. Please install aria2c and try again."
          exit 1
      fi
  fi
}

check_file_special() {
  printf "checking %s\n" "$2"
  if [ -f "./assets/""$1""/""$2""" ]; then
      printf "%s in ./assets/%s checked.\n" "$2" "$1" 
  else
      MISSING=$((MISSING + 1))
      printf "missing: ./assets/%s/%s\n" "$1" "$2"
      [ "$CHECK_ONLY" = "1" ] && return 0
      echo failed. starting download from huggingface.
      if command -v aria2c > /dev/null 2>&1; then
          aria2c --console-log-level=error -c -x 16 -s 16 -k 1M https://huggingface.co/lj1995/VoiceConversionWebUI/resolve/main/"$2" -d ./assets/"$1" -o "$2"
          [ -f "./assets/""$1""/""$2""" ] && echo "download successful." || { echo "please try again!" && exit 1; }
      else
          echo "aria2c command not found. Please install aria2c and try again."
          exit 1
      fi
  fi
}

check_file_pretrained pretrained D32k.pth
check_file_pretrained pretrained D40k.pth
check_file_pretrained pretrained D48k.pth
check_file_pretrained pretrained G32k.pth
check_file_pretrained pretrained G40k.pth
check_file_pretrained pretrained G48k.pth
check_file_pretrained pretrained_v2 f0D40k.pth
check_file_pretrained pretrained_v2 f0G40k.pth
check_file_pretrained pretrained_v2 D40k.pth
check_file_pretrained pretrained_v2 G40k.pth
check_file_pretrained uvr5_weights HP2_all_vocals.pth
check_file_pretrained uvr5_weights HP3_all_vocals.pth
check_file_pretrained uvr5_weights HP5_only_main_vocal.pth
check_file_pretrained uvr5_weights VR-DeEchoAggressive.pth
check_file_pretrained uvr5_weights VR-DeEchoDeReverb.pth
check_file_pretrained uvr5_weights VR-DeEchoNormal.pth
check_file_pretrained uvr5_weights "onnx_dereverb_By_FoxJoy/vocals.onnx"
check_file_special rmvpe rmvpe.pt
check_file_special hubert hubert_base.pt

echo "required files check finished."

if [ "$CHECK_ONLY" = "1" ]; then
    if [ "$MISSING" -eq 0 ]; then
        echo "all required files are present"
        exit 0
    fi
    echo "$MISSING required file(s) missing"
    exit 1
fi
