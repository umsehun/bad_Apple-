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
ret, frame = cap.read()
if ret:
    gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
    resized = cv2.resize(gray, (20, 10))
    
    print('Sample pixel values:', resized[5][:5])
    
    for pixel in resized[5][:5]:
        old_index = int(pixel * (len(ASCII_CHARS) - 1) / 255)
        new_index = min(int(pixel / 255.0 * (len(ASCII_CHARS) - 1)), len(ASCII_CHARS) - 1)
        safe_old = min(max(old_index, 0), len(ASCII_CHARS) - 1)
        print(f'Pixel: {pixel:3d}, Old: {old_index:3d}, New: {new_index:2d}, Old_char: "{ASCII_CHARS[safe_old]}", New_char: "{ASCII_CHARS[new_index]}"')
cap.release()
