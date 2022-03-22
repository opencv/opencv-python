from cv2 import getStructuringElement, MORPH_ELLIPSE

a = getStructuringElement(MORPH_ELLIPSE, (3, 3))
