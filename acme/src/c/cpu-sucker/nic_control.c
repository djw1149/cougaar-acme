/*
 * nic_control
 *
 * Shutdown/Startup/Throtle a NIC
 * 
 * set_flags/clr_flags copied from "ifconfig" in net-tools package.
 */

#include <net/if.h>
#include <sys/ioctl.h>
#include <sys/socket.h>
#include <stdio.h>

#include "nic_control.h"

/*
 * Set interface flags
 */

static int set_flags(const char *ifname, short flag )
{
  struct ifreq ifr;
  int skfd;

  if ((skfd = socket(AF_INET, SOCK_DGRAM, 0)) < 0) {
    return ERR_SOCKET;
  }


  strncpy(ifr.ifr_name, ifname, IFNAMSIZ);
  if (ioctl(skfd, SIOCGIFFLAGS, &ifr) < 0) {
    return ERR_SIOCGIFFLAGS;
  }

  strncpy(ifr.ifr_name, ifname, IFNAMSIZ);
  ifr.ifr_flags |= flag;
  if (ioctl(skfd, SIOCSIFFLAGS, &ifr) < 0) {
    return ERR_SIOCSIFFLAGS;
  }

  return SUCCESS;
}


/*
 * Clear interface flags
 */

static int clr_flags(const char *ifname, short flag )
{
  struct ifreq ifr;
  int skfd;

  if ((skfd = socket(AF_INET, SOCK_DGRAM, 0)) < 0) {
    return ERR_SOCKET;
  }


  strncpy(ifr.ifr_name, ifname, IFNAMSIZ);
  if (ioctl(skfd, SIOCGIFFLAGS, &ifr) < 0) {
    return ERR_SIOCGIFFLAGS;
  }

  strncpy(ifr.ifr_name, ifname, IFNAMSIZ);
  ifr.ifr_flags &= ~flag;
  if (ioctl(skfd, SIOCSIFFLAGS, &ifr) < 0) {
    return ERR_SIOCSIFFLAGS;
  }

  return SUCCESS;
}

int nic_close( const char *name ) {
  return clr_flags(name, IFF_UP);
}
  
int nic_open( const char *name ) {
  return set_flags(name, (IFF_UP | IFF_RUNNING));
}

int nic_throtle( const char *name, int baud ) {
  return SUCCESS;
}


