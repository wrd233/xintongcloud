#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INPUT_IMAGE="${1:-$ROOT_DIR/assets/keyframes/测试图片.png}"
OUTPUT_DIR="${2:-$ROOT_DIR/clips/effect-demos}"

mkdir -p "$OUTPUT_DIR"

COMMON_ENCODE_ARGS=(
  -r 30
  -c:v libx264
  -preset veryfast
  -crf 20
  -pix_fmt yuv420p
  -movflags +faststart
  -x264-params threads=2:lookahead-threads=1
)

run_demo() {
  local output_name="$1"
  local filter_graph="$2"
  local duration="${3:-4}"

  nice -n 10 ffmpeg -y \
    -loop 1 -framerate 30 -t "$duration" -i "$INPUT_IMAGE" \
    -threads 2 -filter_threads 1 -filter_complex_threads 1 \
    -filter_complex "$filter_graph" -map "[v]" \
    -t "$duration" \
    "${COMMON_ENCODE_ARGS[@]}" \
    "$OUTPUT_DIR/$output_name"
}

read -r -d '' DUST_FILTER <<'EOF' || true
[0:v]format=rgba,split=2[bg][fg];
[bg]scale=1280:720:force_original_aspect_ratio=increase,crop=1280:720,boxblur=20:2[bgb];
[fg]scale=1280:720:force_original_aspect_ratio=decrease[fgs];
[bgb][fgs]overlay=(W-w)/2:(H-h)/2,format=rgba[main];
perlin=s=1280x720:r=30:octaves=3:persistence=0.6:xscale=120:yscale=120:tscale=0.08,
format=gray,lut=y='if(gt(val,215),255,0)',format=rgba,
colorchannelmixer=rr=1:gg=0.96:bb=0.88:aa=0.10,gblur=sigma=1.3:steps=1[dust];
[main][dust]overlay=format=auto,format=yuv420p[v]
EOF

read -r -d '' CANDLE_FILTER <<'EOF' || true
[0:v]format=rgba,split=2[bg][fg];
[bg]scale=1280:720:force_original_aspect_ratio=increase,crop=1280:720,boxblur=20:2[bgb];
[fg]scale=1280:720:force_original_aspect_ratio=decrease[fgs];
[bgb][fgs]overlay=(W-w)/2:(H-h)/2,
eq=brightness='0.015+0.010*sin(2*PI*0.75*t)+0.006*sin(2*PI*1.6*t)':contrast=1.03:saturation=1.06,
colorchannelmixer=rr=1.04:gg=1.00:bb=0.95,
format=yuv420p[v]
EOF

read -r -d '' VIGNETTE_FILTER <<'EOF' || true
[0:v]format=rgba,split=2[bg][fg];
[bg]scale=1280:720:force_original_aspect_ratio=increase,crop=1280:720,boxblur=20:2[bgb];
[fg]scale=1280:720:force_original_aspect_ratio=decrease[fgs];
[bgb][fgs]overlay=(W-w)/2:(H-h)/2,
vignette=PI/5,eq=contrast=1.06:saturation=0.94:brightness=-0.01,
format=yuv420p[v]
EOF

read -r -d '' PAPER_FILTER <<'EOF' || true
[0:v]format=rgba,split=2[bg][fg];
[bg]scale=1280:720:force_original_aspect_ratio=increase,crop=1280:720,boxblur=20:2[bgb];
[fg]scale=1280:720:force_original_aspect_ratio=decrease[fgs];
[bgb][fgs]overlay=(W-w)/2:(H-h)/2,
unsharp=5:5:0.9:5:5:0.0,eq=contrast=1.08:saturation=0.84:brightness=0.01,
noise=alls=5:allf=t+u,
format=yuv420p[v]
EOF

read -r -d '' BREATH_FILTER <<'EOF' || true
[0:v]format=rgba,split=2[bg][fg];
[bg]scale=1280:720:force_original_aspect_ratio=increase,crop=1280:720,boxblur=20:2[bgb];
[fg]scale=1280:720:force_original_aspect_ratio=decrease[fgs];
[bgb][fgs]overlay=(W-w)/2:(H-h)/2,
scale=w='1280*(1+0.03*t/4)':h='720*(1+0.03*t/4)':eval=frame:flags=lanczos,
crop=1280:720:(iw-1280)/2:(ih-720)/2,
format=yuv420p[v]
EOF

read -r -d '' GLOW_FILTER <<'EOF' || true
[0:v]format=rgba,split=2[bg][fg];
[bg]scale=1280:720:force_original_aspect_ratio=increase,crop=1280:720,boxblur=20:2[bgb];
[fg]scale=1280:720:force_original_aspect_ratio=decrease[fgs];
[bgb][fgs]overlay=(W-w)/2:(H-h)/2,format=rgba[main];
nullsrc=s=1280x720:d=4,format=rgba,
geq=r='255':g='220':b='120':a='70*exp(-((X-875)^2+(Y-165)^2)/38000)',
gblur=sigma=18[glow];
[main][glow]overlay=format=auto,eq=contrast=1.03:saturation=1.05,format=yuv420p[v]
EOF

read -r -d '' SHADOW_FILTER <<'EOF' || true
[0:v]format=rgba,split=2[bg][fg];
[bg]scale=1280:720:force_original_aspect_ratio=increase,crop=1280:720,boxblur=20:2[bgb];
[fg]scale=1280:720:force_original_aspect_ratio=decrease[fgs];
[bgb][fgs]overlay=(W-w)/2:(H-h)/2,format=rgba[main];
nullsrc=s=1280x720:d=4,format=rgba,
drawbox=x=618:y=0:w=44:h=720:color=black@0.28:t=fill,
drawbox=x=0:y=0:w=72:h=720:color=black@0.10:t=fill,
drawbox=x=1208:y=0:w=72:h=720:color=black@0.10:t=fill,
drawbox=x=0:y=620:w=1280:h=100:color=black@0.08:t=fill,
gblur=sigma=26[shadow];
[main][shadow]overlay=format=auto,format=yuv420p[v]
EOF

read -r -d '' MIST_FILTER <<'EOF' || true
[0:v]scale=1920:1440:flags=lanczos,crop=1280:720:170:150,trim=duration=2.3,setpts=PTS-STARTPTS[left];
[0:v]scale=2080:1560:flags=lanczos,crop=1280:720:640:170,trim=duration=2.3,setpts=PTS-STARTPTS[right];
[left][right]xfade=transition=hblur:duration=0.7:offset=1.6,format=rgba[shot];
perlin=s=1280x720:r=30:octaves=2:persistence=0.55:xscale=280:yscale=160:tscale=0.05,
format=rgba,colorchannelmixer=rr=0.96:gg=0.96:bb=0.96:aa=0.06,gblur=sigma=16[mist];
[shot][mist]overlay=format=auto,eq=contrast=1.02:saturation=0.98,format=yuv420p[v]
EOF

run_demo "测试图片_effect01_dust_720p.mp4" "$DUST_FILTER"
run_demo "测试图片_effect02_candle_720p.mp4" "$CANDLE_FILTER"
run_demo "测试图片_effect03_vignette_720p.mp4" "$VIGNETTE_FILTER"
run_demo "测试图片_effect04_paper_texture_720p.mp4" "$PAPER_FILTER"
run_demo "测试图片_effect05_breath_720p.mp4" "$BREATH_FILTER"
run_demo "测试图片_effect06_glow_720p.mp4" "$GLOW_FILTER"
run_demo "测试图片_effect07_page_shadow_720p.mp4" "$SHADOW_FILTER"
run_demo "测试图片_effect08_mist_transition_720p.mp4" "$MIST_FILTER"

printf 'Generated demos in %s\n' "$OUTPUT_DIR"
