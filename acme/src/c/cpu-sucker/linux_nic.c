/*
 * JNI interface for NIC Control
 */

#include "linux_nic.h"
#include "nic_control.h"

#include <stdio.h>
#include <malloc.h>

void throwNICException( JNIEnv *env, const char *device, int RC )
{
  char *message = (char *)malloc(100 * sizeof(char));
  jclass utbExcept =
    (*env)->FindClass(env, "org.cougaar.tools.utb.exception.UTBException");

  sprintf(message, "[%s] %s", device, strerror( RC ));
  (*env)->ThrowNew(env, utbExcept, message);
  free( message );
}


void JNICALL Java_org_cougaar_tools_utb_hardware_linux_LinuxNICControl_openNic
(JNIEnv *env, jclass clazz, jstring name)
{
  jboolean iscopy;
  int RC;
  const char *device = (*env)->GetStringUTFChars(env, name, &iscopy);

  RC = nic_open( device );

  if (RC != SUCCESS) 
    throwNICException(env, device, RC);

  (*env)->ReleaseStringUTFChars(env, name, device);
  return;
}


void JNICALL Java_org_cougaar_tools_utb_hardware_linux_LinuxNICControl_closeNic
(JNIEnv *env, jclass clazz, jstring name)
{
  jboolean iscopy;

  int RC;
  const char* device = (*env)->GetStringUTFChars(env, name, &iscopy);

  RC = nic_close( device );

  if (RC != SUCCESS) 
    throwNICException(env, device, RC);

  (*env)->ReleaseStringUTFChars(env, name, device);
  return;
}
