/*
 * Header file for "nic_control.c"
 */
#define SUCCESS 0
#define ERR_SIOCGIFFLAGS -1
#define ERR_SIOCSIFFLAGS -2
#define ERR_SOCKET -4


extern int nic_open( const char *name );
extern int nic_close( const char *name );
extern int nic_throtle( const char *name, int baud );
