#!/bin/sh

# ==== Globals ======================================================================
FFMPEG=/usr/local/bin/ffmpeg            # Path to ffmpeg
GIFSICLE=/usr/local/bin/gifsicle        # Path to gifsicle
PALETTE_DIR=~/Desktop/palette.png       # Where to save palette
OUTPUT_DIR=~/Desktop/output.gif         # Where to save the gif
OPTIMIZED_DIR=~/Desktop/optimized.gif   # Where to save the optimized gif
FILENAME=$1                             # The file name
# ===================================================================================

# ==== Default filters ==============================================================
fps="15"                        # Frames per second
scale="540"                     # Scale for final gif
unsharp="7:7:2.5:5:5:0.0"       # Sharpen filter (default values: 5:5:1.0:5:5:0.0)
# ===================================================================================

function generate_gif () {
    echo "Generating GIF ..."

    flags="lanczos[x];[x][1:v]paletteuse"
    FFMPEG -v warning -i $FILENAME -i $PALETTE_DIR -lavfi "fps=$fps,unsharp=$unsharp,scale=$scale:-1:flags=$flags" $OUTPUT_DIR -y
}

function generate_palette () {
    echo "Generating palette ... "

    flags="lanczos,palettegen"
    FFMPEG -v warning -i $FILENAME -vf "fps=$fps,scale=$scale:-1:flags=lanczos,palettegen" $PALETTE_DIR -y
}

function clean () {
    # Delete the palette
    rm -f $PALETTE_DIR

    # Delete the un-optimized gif
    rm -f $OUTPUT_DIR

    # Add your own cleaning here
}

# INIT PROGRAM
if [ $# -eq 0 ]
    then
        echo "Please enter a file name."
        exit 1
elif [ ! -f "$FILENAME" ]
    then
        echo "File $FILENAME does not exist in the current directory."
        exit 1
else
    start=$(date +%s)

    # Remove any existing palettes
    rm -f PALETTE_DIR

    # Generate new palette
    generate_palette

    # Generate gif
    generate_gif

    # Optimize using gifsicle
    GIFSICLE -O3 $OUTPUT_DIR -o $OPTIMIZED_DIR

    # Clean up
    clean

    # Display final file size
    mb=$(du -h $OPTIMIZED_DIR | awk '{print $1}')
    echo "\nFile size: ${mb}"

    # Display elapsed time
    end=$(date +%s)
    elapsed=$(( end - start ))

    echo "Elapsed time: $elapsed seconds"
fi
