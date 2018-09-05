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

lineno=0
filehash=`$md5_cmd $PHRASE_FILE | cut -f1 -d' '`

while read line; do
    # Ignore comments (a hash '#' begins a comment) and skip lines that don't
    # contain any sounds.
    line=`echo "$line" | sed 's/#.*$//'`

    if ! echo "$line" | grep '[a-z]' > /dev/null; then
        continue
    fi

    # Base the filename off of the hash of the text; to pseudo-randomize order
    # Also use the hash of the entire file and the line number for computing the
    # hash, to allow the same text to occur multiple times in the same file or
    # across files.
    phrase_filename=`echo $filehash:$lineno:$line | $md5_cmd | cut -f1 -d' '`
    lineno=$(( $lineno + 1 ))

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
