import sys
import numpy as np
import matplotlib
import matplotlib.pylab as pylab
import matplotlib.pyplot as plt

def get_timestamp(filename, ch=0):
    f = open(filename, 'rb')
    ftype = np.dtype([
        ('flags', '>u1'),
        ('timestamp', '>u4')
    ])
    a = np.fromfile(f, dtype=ftype)
    flags = a['flags']
    timestamp = a['timestamp']
    
    # Filter events containing channel ch
    timestamp = timestamp[flags & (1<<ch) != 0]
    return timestamp

if len(sys.argv) not in (3,4) or (len(sys.argv) == 4 and sys.argv[3] not in ('time', 'hist')):
    print('usage: %s acq_file channel [hist|time]' % sys.argv[0])
    sys.exit(1)

filename = sys.argv[1]
channel = int(sys.argv[2])
plottype = 'hist' if len(sys.argv) == 3 else sys.argv[3]

chunksize = int(1e7)

isi = np.array(np.diff(get_timestamp(filename, channel)), dtype=np.float64)
print(repr(('mean', isi.mean(), 'std', isi.std())))

plt.rc('text', usetex=True)
plt.rc('font',**{'family':'sans-serif','sans-serif':['Helvetica']})

if plottype == 'time':
    for i in xrange(0, len(isi), chunksize):
        print('start @chunk %d' % i)
        window = isi[i:i+chunksize]
        plt.plot(1.e-6*window.cumsum(), window, 'k.')
        plt.ylabel(r'$\Delta t$ ($\mu$s)')
        plt.xlabel(r'$t$ (s)')
        dim = plt.axis()
        plt.axis(dim[:2] + (dim[2]-2, dim[3]+2))
        ax = plt.gca()
        y_formatter = matplotlib.ticker.ScalarFormatter(useOffset=False)
        ax.yaxis.set_major_formatter(y_formatter)
        plt.tight_layout()
        plt.show()
elif plottype == 'hist':
    y, x, _ = plt.hist(isi, color='#888888', log=True)
    plt.ylabel(r'Number of occurrences')
    plt.xlabel(r'$\Delta t$ ($\mu$s)')
    ax = plt.gca()
    x_formatter = matplotlib.ticker.ScalarFormatter(useOffset=False)
    ax.xaxis.set_major_formatter(x_formatter)
    plt.xticks(np.round(x[pylab.find(y>0)]))
    plt.tight_layout()
    plt.show()
