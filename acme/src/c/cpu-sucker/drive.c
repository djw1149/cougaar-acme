
#include <sys/mount.h>

#include "drive.h"

int unmount( char *directory ) {
  return umount( directory );
}
