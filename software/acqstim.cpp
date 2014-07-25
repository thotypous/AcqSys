#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>
#include <assert.h>
#include <time.h>
#include "jtag_atlantic.h"
#include "common.h"

static const int rx_item_size = 5;
static const int tx_item_size = 3;
static const useconds_t usleep_time = 800000;

static uint8_t rxbuf[rx_item_size*7000];
static uint8_t txbuf[tx_item_size*500];
static unsigned int txbuf_pos = 0;

static JTAGATLANTIC *atlantic;

#define SHOWDBG(fmt, ...) fprintf(stderr, fmt, ##__VA_ARGS__)

static void try_reopen() {
    jtagatlantic_close(atlantic);
    atlantic = jtagatlantic_open(NULL, -1, -1, "acqstim");
    if(!atlantic) exit(0);  // device removed from USB port
    SHOWDBG("JTAG LIBRARY FAILURE -- DEVICE REOPENED\n");
}

static void dotx(bool send_start_cmd=false) {
    int nread = fread(&txbuf[txbuf_pos], 1,
        sizeof(txbuf) - txbuf_pos - (send_start_cmd?tx_item_size:0),
        stdin);
    assert(nread >= 0);
    nread += txbuf_pos;
    if(send_start_cmd)
        txbuf[nread++] = 0x80; // start command
    int nwritten = jtagatlantic_write(atlantic, (char*)txbuf, nread);
    if(nwritten < 0) {
        try_reopen();
        nwritten = 0;
    }
    SHOWDBG("TX: succesfully sent %d bytes\n", nwritten);
    txbuf_pos = nread - nwritten;
    if(txbuf_pos != 0) {
        SHOWDBG("TX: read %d bytes, written only %d -- buffering\n", nread, nwritten);
        memmove(txbuf, &txbuf[nwritten], txbuf_pos);
    }
}

static void dorx() {
    int nread = jtagatlantic_read(atlantic, (char*)rxbuf, sizeof(rxbuf));
    if((nread < 0) || nread > (int)sizeof(rxbuf)) {
        try_reopen();
        nread = 0;
    }
    SHOWDBG("RX: succesfully received %d bytes\n", nread);
    int nwritten = fwrite(rxbuf, 1, nread, stdout);
    assert(nwritten == nread);
    fflush(stdout);
}

int main() {
    atlantic = jtagatlantic_open(NULL, -1, -1, "acqstim");
    if(!atlantic) {
        show_err();
        return 1;
    }
    show_info(atlantic);

    dotx(true);
    
    while(1) {
        dorx();
        dotx();
        usleep(usleep_time);
    }
    
    jtagatlantic_close(atlantic);
    return 0;
}
