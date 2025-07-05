import cv2
import numpy as np

ASCII_CHARS = [
    " ", ".", "'", "`", "^", "\"", ",", ":", ";", "I", "l", "!", "i", ">",
    "<", "~", "+", "_", "-", "?", "]", "[", "}", "{", "1", ")", "(", "|",
    "\\", "/", "t", "f", "j", "r", "x", "n", "u", "v", "c", "z", "X", "Y",
    "U", "J", "C", "L", "Q", "0", "O", "Z", "m", "w", "q", "p", "d", "b",
    "k", "h", "a", "o", "*", "#", "M", "W", "&", "8", "%", "B", "@"
]

def convert_to_ascii(image):
    ascii_str = ""
    for row in image:
        for pixel in row:
            ascii_index = int(pixel * (len(ASCII_CHARS) - 1) / 255)
            ascii_str += ASCII_CHARS[ascii_index]
        ascii_str += "\n"
    return ascii_str

cap = cv2.VideoCapture('assets/ascii_frames/bad_apple.mp4')
frame_skip = 2
frame_count = 0
output_count = 0

# 3000번째 출력 파일 생성 과정 시뮬레이션
while output_count < 3001:
    ret, frame = cap.read()
    if not ret:
        break
    
    if frame_count % frame_skip == 0:
        if output_count == 3000:  # frame_03000.txt에 해당
            print(f"Processing frame_count: {frame_count}, output_count: {output_count}")
            gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
            height = int(gray.shape[0] * 80 / gray.shape[1])
            resized = cv2.resize(gray, (80, height))
            
            print(f"Resized shape: {resized.shape}")
            print(f"Sample pixels: {resized[10][:10]}")
            print(f"Min: {resized.min()}, Max: {resized.max()}")
            
            # ASCII 변환
            ascii_frame = convert_to_ascii(resized)
            
            # 첫 3줄만 출력
            lines = ascii_frame.split('\n')[:3]
            print("First 3 lines of ASCII:")
            for i, line in enumerate(lines):
                print(f"Line {i}: '{line[:20]}...'")
            
            break
        output_count += 1
    
    frame_count += 1

cap.release()
