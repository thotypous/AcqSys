import sys
import matplotlib.pyplot as plt
import numpy as np

a = np.fromfile(sys.stdin, dtype='>u2')
for ch in xrange(4):
    plt.plot(a[ch::4], alpha=.7, label='ch%d'%ch)
plt.legend()
plt.show()