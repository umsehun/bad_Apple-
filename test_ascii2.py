import cv2
import numpy as np

ASCII_CHARS = [
    " ", ".", "'", "`", "^", "\"", ",", ":", ";", "I", "l", "!", "i", ">",
    "<", "~", "+", "_", "-", "?", "]", "[", "}", "{", "1", ")", "(", "|",
    "\\", "/", "t", "f", "j", "r", "x", "n", "u", "v", "c", "z", "X", "Y",
    "U", "J", "C", "L", "Q", "0", "O", "Z", "m", "w", "q", "p", "d", "b",
    "k", "h", "a", "o", "*", "#", "M", "W", "&", "8", "%", "B", "@"
]

cap = cv2.VideoCapture('assets/ascii_frames/bad_apple.mp4')

# 프레임 3000번으로 이동 (뒤쪽)
cap.set(cv2.CAP_PROP_POS_FRAMES, 3000)
ret, frame = cap.read()
if ret:
    gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
    resized = cv2.resize(gray, (20, 10))
    
    print('Frame 3000 pixel values:', resized[5][:10])
    print('Min:', resized.min(), 'Max:', resized.max())
    
    # 다양한 픽셀 값 테스트
    test_pixels = [0, 64, 128, 192, 255]
    print('\nASCII conversion test:')
    for pixel in test_pixels:
        old_index = int(pixel * (len(ASCII_CHARS) - 1) / 255)
        new_index = min(int(pixel / 255.0 * (len(ASCII_CHARS) - 1)), len(ASCII_CHARS) - 1)
        print(f'Pixel: {pixel:3d}, Index: {new_index:2d}, Char: "{ASCII_CHARS[new_index]}"')
else:
    print("Could not read frame 3000")

cap.release()
