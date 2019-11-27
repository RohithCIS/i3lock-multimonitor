#!/bin/bash

#Constants
DISPLAY_RE="([0-9]+)x([0-9]+)\\+([0-9]+)\\+([0-9]+)" # Regex to find display dimensions
FOLDER=`dirname "$BASH_SOURCE"` # Current folder
CACHE_FOLDER="$FOLDER"/img/cache/ # Cache folder
if ! [ -e $CACHE_FOLDER ]; then
    mkdir -p $CACHE_FOLDER
fi

#Passed arguments
while getopts ":i:a:" opt; do
    case $opt in
        i) arg_image="$OPTARG"
        ;;
        a) lock_args="$OPTARG"
        ;;
        \?) echo "Invalid option -$OPTARG" >&2 && exit 1
        ;;
    esac
done

#Image paths
if [ "$arg_image" ]; then
    BKG_IMG="$arg_image"  # Passed image
else
    BKG_IMG="$FOLDER/img/background.png"  # Default
fi

if ! [ -e "$BKG_IMG" ]; then
    echo "No background image! Exiting..."
    exit 2
fi

MD5_BKG_IMG=$(md5sum $BKG_IMG | cut -c 1-10)
MD5_SCREEN_CONFIG=$(xrandr | md5sum - | cut -c 1-32) # Hash of xrandr output
OUTPUT_IMG="$CACHE_FOLDER""$MD5_SCREEN_CONFIG"."$MD5_BKG_IMG".png # Path of final image
OUTPUT_IMG_WIDTH=0 # Decide size to cover all screens
OUTPUT_IMG_HEIGHT=0 # Decide size to cover all screens

#i3lock command
LOCK_BASE_CMD="i3lock -i $OUTPUT_IMG"
if [ "$lock_args" ]; then
        LOCK_ARGS="$lock_args"  # Passed command
else
        LOCK_ARGS="-t -e"  # Default
fi
LOCK_CMD="$LOCK_BASE_CMD $LOCK_ARGS"

if [ -e $OUTPUT_IMG ]
then
    # Lock screen since image already exists
    RES=$(xrandr | grep 'current' | sed -E 's/.*current\s([0-9]+)\sx\s([0-9]+).*/\1x\2/')
    ffmpeg -f x11grab -video_size $RES -y -i $DISPLAY -i $OUTPUT_IMG -filter_complex "boxblur=5:1,overlay=(main_w-overlay_w)/2:(main_h-overlay_h)/2" -vframes 1 /tmp/screen.png -loglevel quiet
    i3lock -t -i /tmp/screen.png
    rm /tmp/screen.png
    exit 0
fi

#Execute xrandr to get information about the monitors:
while read LINE
do
  #If we are reading the line that contains the position information:
  if [[ $LINE =~ $DISPLAY_RE ]]; then
    #Extract information and append some parameters to the ones that will be given to ImageMagick:
    SCREEN_WIDTH=${BASH_REMATCH[1]}
    SCREEN_HEIGHT=${BASH_REMATCH[2]}
    SCREEN_X=${BASH_REMATCH[3]}
    SCREEN_Y=${BASH_REMATCH[4]}
    
    CACHE_IMG="$CACHE_FOLDER""$SCREEN_WIDTH"x"$SCREEN_HEIGHT"."$MD5_BKG_IMG".png
    ## if cache for that screensize doesnt exist
    if ! [ -e $CACHE_IMG ]
    then
    # Create image for that screensize
        eval convert '$BKG_IMG' '-background' 'none' '-gravity' 'Center' '-extent' '${SCREEN_WIDTH}X${SCREEN_HEIGHT}^' '-crop' '${SCREEN_WIDTH}X${SCREEN_HEIGHT}+0+0' '+repage' '$CACHE_IMG'
    fi

    # Decide size of output image
    if (( $OUTPUT_IMG_WIDTH < $SCREEN_WIDTH+$SCREEN_X )); then OUTPUT_IMG_WIDTH=$(($SCREEN_WIDTH+$SCREEN_X)); fi;
    if (( $OUTPUT_IMG_HEIGHT < $SCREEN_HEIGHT+$SCREEN_Y )); then OUTPUT_IMG_HEIGHT=$(( $SCREEN_HEIGHT+$SCREEN_Y )); fi;

    PARAMS="$PARAMS $CACHE_IMG -colorspace sRGB -geometry +$SCREEN_X+$SCREEN_Y -composite "
  fi
done <<<"`xrandr`"

#Execute ImageMagick:
eval convert -size ${OUTPUT_IMG_WIDTH}x${OUTPUT_IMG_HEIGHT} 'xc:none' $OUTPUT_IMG
eval convert $OUTPUT_IMG $PARAMS $OUTPUT_IMG

RES=$(xrandr | grep 'current' | sed -E 's/.*current\s([0-9]+)\sx\s([0-9]+).*/\1x\2/')
ffmpeg -f x11grab -video_size $RES -y -i $DISPLAY -i $OUTPUT_IMG -filter_complex "boxblur=5:1,overlay=(main_w-overlay_w)/2:(main_h-overlay_h)/2" -vframes 1 /tmp/screen.png -loglevel quiet
i3lock -t -i /tmp/screen.png
