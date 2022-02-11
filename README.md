# ffmpeg-gif
Bash script to generate GIFs using ffmpeg and gifsicle from a video.

# Prerequisites
You must have `ffmpeg` and `gifsicle` installed on your system.

# How to use
It is recommended that you use a video of 10 seconds max, and a default scale of 540px to have decent file sizes.
Please see sample outputs below for gifs with different scales/fps.

By default, this script will generate three files and place them on your `~/Desktop`:
1. `palette.png` – ffmpeg will generate this palette from your video
2. `output.gif` – the gif that is generated by ffmpeg
3. `optimized.gif` – an optimized/compressed version of `output.gif`

To generate a gif run: `./gif.sh path-to-video.mp4`

By default, gifs will be scaled to 540px at 15fps. Feel free to fork the repository and change your settings to your liking.

# Sample run
```
./gif.sh ronaldo.mov
Generating palette ...
Generating GIF ...

File size: 15M
Elapsed time: 10 second
```

# Sample output

#### Scaled to 320px at 15fps (5.4 MB)
![ronaldo-320-15fps](https://github.com/carlitosz/ffmpeg-gif/blob/master/320-15.gif)

#### Scaled to 320px at 20fps (7.2 MB)
![ronaldo-320-20fps](https://github.com/carlitosz/ffmpeg-gif/blob/master/320-20.gif)

#### Scaled to 540px at 15fps (15 MB)
![ronaldo-540-15fps](https://github.com/carlitosz/ffmpeg-gif/blob/master/540-15.gif)