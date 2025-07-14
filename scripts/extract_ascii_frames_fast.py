#!/usr/bin/env python3
"""extract_ascii_frames_fast.py
------------------------------------------------------------
FFmpeg 로 비디오를 한 번만 디코딩/스케일/FPS 변환하여 bgr24 RAW 스트림으로
읽어들이고, 파이썬 단일 프로세스에서 ASCII 프레임(txt)으로 저장한다.
장점:
  • 프로세스 간 numpy 직렬화 없음 → 메모리·IPC 병목 제거
  • FFmpeg C-레벨 멀티스레드 디코딩으로 최대 10× 속도
  • 코드 단순화, 플랫폼 deadlock 회피
"""
import argparse
import os
import subprocess
import sys
import time
from typing import List
import itertools

import cv2
import numpy as np

# 70단계 문자 램프 (따옴표/역슬래시 이스케이프)
ASCII_GRADIENT = " .`^\",:;Il!i><~+_-?][}{1)(|\\/*tfjrxnuvczXYUJCLQ0OZmwqpdbkhao*#MW&8%B@$"
# 기본 8단계(속도)와 70단계(고품질) LUT 준비
LUT_8 = np.array(list(' .-*%#@'), dtype='<U1')
LUT_70 = np.array(list(ASCII_GRADIENT), dtype='<U1')

# LUT → 256-level 문자 매핑 테이블 사전 계산 (uint8 인덱스 → 문자)
CHAR_MAP_8 = np.array([LUT_8[(i * (len(LUT_8)-1)) // 255] for i in range(256)], dtype='<U1')
CHAR_MAP_70 = np.array([LUT_70[(i * (len(LUT_70)-1)) // 255] for i in range(256)], dtype='<U1')

# 전역 설정값 (인자에 의해 갱신)
USE_HIGH = True
USE_DITHER = 'none'  # 'none' | 'fs' | 'ordered'

# 8×8 Bayer 행렬 (ordered dither)
_BAYER_8 = (
    np.array([
        [ 0, 48, 12, 60,  3, 51, 15, 63],
        [32, 16, 44, 28, 35, 19, 47, 31],
        [ 8, 56,  4, 52, 11, 59,  7, 55],
        [40, 24, 36, 20, 43, 27, 39, 23],
        [ 2, 50, 14, 62,  1, 49, 13, 61],
        [34, 18, 46, 30, 33, 17, 45, 29],
        [10, 58,  6, 54,  9, 57,  5, 53],
        [42, 26, 38, 22, 41, 25, 37, 21]
    ], dtype=np.uint8)
)


# ------------------------------------------------------------
# 디더링 구현
# ------------------------------------------------------------

def _fs_dither(gray: np.ndarray, lut_chars: np.ndarray) -> List[str]:
    """ Floyd-Steinberg 오차확산. 반환: ASCII 문자열 리스트(행 단위) """
    h, w = gray.shape
    gray_f = gray.astype(np.int16)
    levels = len(lut_chars) - 1
    ascii_rows: List[str] = []

    for y in range(h):
        row_chars = []
        for x in range(w):
            old = gray_f[y, x]
            new_level = (old * levels + 127) // 255  # rounding
            new_val = (new_level * 255) // levels
            error = old - new_val
            row_chars.append(str(lut_chars[new_level]))

            # 오차 분배
            if x + 1 < w:
                gray_f[y, x+1] += error * 7 // 16
            if y + 1 < h:
                if x > 0:
                    gray_f[y+1, x-1] += error * 3 // 16
                gray_f[y+1, x] += error * 5 // 16
                if x + 1 < w:
                    gray_f[y+1, x+1] += error * 1 // 16

        ascii_rows.append("".join(row_chars))
    return ascii_rows


def _ordered_dither(gray: np.ndarray, lut_chars: np.ndarray) -> List[str]:
    """8×8 Bayer ordered dither"""
    h, w = gray.shape
    tiled_threshold = np.tile(_BAYER_8, (h // 8 + 1, w // 8 + 1))[:h, :w]
    levels = len(lut_chars) - 1
    # threshold 정규화: 0~63 → 0~255 로 확장 후 추가
    dithered = gray + (tiled_threshold * 4) - 128  # shift 약간 대비 향상
    dithered = np.clip(dithered, 0, 255).astype(np.uint8)
    ascii_img = lut_chars[(dithered * levels) // 255]
    return ["".join(row) for row in ascii_img]


def bgr_frame_to_ascii(frame: np.ndarray) -> str:
    """BGR 프레임 → ASCII 문자열 (디더링·고품질 지원)"""
    gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)

    # 대비 향상
    clahe = cv2.createCLAHE(clipLimit=3.0, tileGridSize=(8, 8))
    enhanced = clahe.apply(gray)

    # 문자 LUT 준비
    lut_chars = CHAR_MAP_70 if USE_HIGH else CHAR_MAP_8

    # 디더링 분기
    if USE_DITHER == 'fs':
        ascii_rows = _fs_dither(enhanced, lut_chars)
    elif USE_DITHER == 'ordered':
        ascii_rows = _ordered_dither(enhanced, lut_chars)
    else:
        ascii_img = lut_chars[enhanced]
        ascii_rows = ["".join(row) for row in ascii_img]

    # 파일 말미 개행 추가 → 플레이어에서 라인 깨짐 방지
    return "\n".join(ascii_rows) + "\n"


def stream_frames_ffmpeg(path: str, width: int, height: int, fps: int):
    """FFmpeg subprocess 로부터 BGR raw frame 을 yield"""
    cmd = [
        'ffmpeg', '-loglevel', 'error', '-i', path,
        '-vf', f'fps={fps},scale={width}:{height}',
        '-f', 'rawvideo', '-pix_fmt', 'bgr24', '-'
    ]
    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE)
    frame_bytes = width * height * 3
    if proc.stdout is None:
        raise RuntimeError('Failed to open ffmpeg stdout')

    while True:
        buf = proc.stdout.read(frame_bytes)
        if len(buf) < frame_bytes:
            break
        yield np.frombuffer(buf, dtype=np.uint8).reshape((height, width, 3))

    proc.stdout.close()
    proc.wait()


def extract_frames(input_path: str, output_dir: str, width: int, height: int, fps: int):
    os.makedirs(output_dir, exist_ok=True)
    start = time.time()
    processed = 0

    print(f'🎬 {input_path}')
    print(f'📐 {width}x{height} @ {fps}fps')

    for frame in stream_frames_ffmpeg(input_path, width, height, fps):
        ascii_txt = bgr_frame_to_ascii(frame)
        out_path = os.path.join(output_dir, f'frame_{processed:05d}.txt')
        with open(out_path, 'w', encoding='utf-8') as fp:
            fp.write(ascii_txt)

        processed += 1
        if processed % 100 == 0:
            elapsed = time.time() - start
            speed = processed / elapsed if elapsed else 0
            print(f'\r📈 {processed} frames | {speed:.1f} fps', end='', flush=True)

    duration = time.time() - start
    print(f'\n✅ 완료! 총 {processed} 프레임, {duration:.1f}s, 평균 {processed/duration:.1f} fps')


def main():
    p = argparse.ArgumentParser(description='Fast ASCII frame extractor (FFmpeg)')
    p.add_argument('-i', '--input', required=True, help='Input video path')
    p.add_argument('-o', '--output', default='ascii_frames', help='Output directory')
    p.add_argument('-w', '--width', type=int, default=140, help='Frame width')
    p.add_argument('-ht', '--height', type=int, default=50, help='Frame height')
    p.add_argument('-f', '--fps', type=int, default=120, help='Target FPS')
    p.add_argument('--quality', choices=['fast', 'high'], default='high', help='ASCII LUT quality')
    p.add_argument('--dither', choices=['none', 'fs', 'ordered'], default='none', help='Dithering algorithm')
    args = p.parse_args()

    global USE_HIGH, USE_DITHER
    USE_HIGH = args.quality == 'high'
    USE_DITHER = args.dither
    extract_frames(args.input, args.output, args.width, args.height, args.fps)


if __name__ == '__main__':
    main() 