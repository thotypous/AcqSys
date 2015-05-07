include ../config.mk

CXX=g++
CC=$(CXX)
CXXFLAGS=-O2 -Wall
LDFLAGS=-L. -Wl,-rpath=.
LDLIBS=-ljtag_atlantic -ljtag_client

EXECUTABLE=acqstim
OBJS=acqstim.o common.o
EXT_LIBS=libjtag_atlantic.so libjtag_client.so

all: $(EXECUTABLE)
acqstim: $(OBJS) $(EXT_LIBS)
clean:
	rm -f $(EXECUTABLE) $(OBJS)
distclean: clean
	rm -f $(EXT_LIBS)

%.so: $(QUARTUS_ROOTDIR)/$(OSPLATFORM)/%.so
	cp -f $< $@
