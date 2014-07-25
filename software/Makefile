CXX=g++
CC=$(CXX)
CXXFLAGS=-O2 -Wall
LDFLAGS=-L. -Wl,-rpath=.
LDLIBS=-ljtag_atlantic -ljtag_client
all: acqstim
acqstim: acqstim.o common.o
clean:
	rm -f acqstim acqstim.o common.o
