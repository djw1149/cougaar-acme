/*
 * main
 *
 * This is a driver for the "process" package.
 */

#include "nic_control.h"
#include "cpu_sucker.h"
#include "power_off.h"
#include "drive.h"

#include <stdio.h>
#include <string.h>
#include <errno.h>

int main(int argc, char *argv[]) {

  if (strcmp( argv[0], "cpu_sucker" ) == 0) {
    int on_time, off_time;
    if (argc < 3) {
      fprintf(stderr, "Usage: %s on_time off_time\n", argv[0]);
      exit(-1);
    }
    
    on_time = atoi(argv[1]);
    off_time = atoi(argv[2]);

    cpu_sucker( on_time, off_time );

    /*
    while (1) {
      sleep(1000);
    }
    */
  }

  if (strcmp( argv[0], "nic_control" ) == 0) {
    if (argc < 3) {
      fprintf(stderr, "Usage: %s device [open|close]\n", argv[0]);
      exit(-1);
    }

    if (strcmp(argv[2], "open") == 0) {
      nic_open( argv[1] );
    }

    if (strcmp(argv[2], "close") == 0) {
      nic_close( argv[1] );
    }
  }

  if (strcmp( argv[0], "power_off" ) == 0) {
    int RC = power_off();
    fprintf(stderr, "%s\n", strerror(errno));
  }

  if (strcmp( argv[0], "unmount" ) == 0) {
    int RC = unmount( argv[1] );
    fprintf(stderr, "%s\n", strerror(errno));
  }
}

