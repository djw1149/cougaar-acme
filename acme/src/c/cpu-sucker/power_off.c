/*
 * power_off
 *
 * Shutdown the machine uncleanly.
 */

#include <sys/reboot.h>

#include "power_off.h"

int power_off() {
  return reboot( RB_POWER_OFF );
}

int restart() {
  return reboot( RB_AUTOBOOT );
}
