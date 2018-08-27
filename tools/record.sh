#!/bin/sh

set -e

if [ $# -lt 2 ]; then
    echo "Usage: $0 SPEAKER PHRASE_FILE"
    exit 1
fi

SPEAKER=$1
PHRASE_FILE=$2

# GNU-type systems: md5sum; BSD-type systems: md5
if which md5sum > /dev/null; then
    md5_cmd="md5sum"
elif which md5 > /dev/null; then
    md5_cmd="md5"
else
    echo "Can't find md5 command!"
    exit 1
fi

dir="`dirname $0`/../speakers/$SPEAKER"
mkdir -p "$dir/txt" "$dir/wav"

while read line; do
    # Base the filename off of the hash of the text; to pseudo-randomize order
    phrase_filename=`echo $line | $md5_cmd | cut -f1 -d' '`
    # Convert xifan hol to Okrandian transliteration for display purposes
    phrase_translit=`echo $line | sed -e s/d/D/g -e s/g/G/g -e s/f/ng/g \
                     -e s/h/H/g -e s/c/ch/g -e s/G/gh/g -e s/i/I/g -e s/k/K/g \
                     -e s/q/Q/g -e s/K/q/g -e s/s/S/g -e s/x/tlh/g -e s/z/\'/g`

    while ! [ -f "$dir/txt/${phrase_filename}.txt" ] || \
          ! [ -f "$dir/wav/${phrase_filename}.wav" ]; do
        echo "Prepare to say: \"$phrase_translit\""
        echo "Press enter to begin recording, then press enter again to stop."

        # The input is ignored, but specify a storage variable name for shells
        # that require it.
        read REPLY < /dev/tty

        tmpfile="$dir/wav/${phrase_filename}.stereo.wav"
        rec "$tmpfile" &

        read REPLY < /dev/tty
        while kill $! 2> /dev/null; do
            sleep 0.1
        done

        echo "Finished recording. (r)eplay, (e)rase, or (w)rite?"
        while read response; do
            r=`echo $response | cut -c1`

            if [ "$r" = "r" ]; then
                play "$tmpfile"
            fi

            if [ "$r" = "w" ]; then
                sox "$tmpfile" "$dir/wav/${phrase_filename}.wav" channels 1
                echo $line > "$dir/txt/${phrase_filename}.txt"
            fi

            if [ "$r" = "e" ] || [ "$r" = "w" ]; then
                rm "$tmpfile"
                break
            fi

            echo "(r)eplay, (e)rase, or (w)rite?"
        done < /dev/tty
    done
done < "$PHRASE_FILE"
