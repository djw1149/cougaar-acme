#include "ruby.h"
#include <windows.h>
#include "lib\win32\process.h"

VALUE cProcess, cProcessError;
VALUE fname, path;
int os_supported;
static VALUE child_pids;

static VALUE process_kill(int argc, VALUE *argv, VALUE module)
{
   int i, signal;
   HANDLE hProcess, hThread;
   DWORD dwPid, dwThreadId;
   DWORD dwTimeout = 5;
   VALUE killed_pids = rb_ary_new();

   if(argc < 2){
      rb_raise(rb_eArgError, "wrong number of arguments -- kill(sig, pid...)");
   }

   signal = NUM2INT(argv[0]);
   
   if( (signal < 0) || (signal > 9) ){
      rb_raise(rb_eArgError, "bad signal number -- must use 0-9");
   }

   for(i = 1; i < argc; i++){
      dwPid = NUM2INT(argv[i]);

      /*******************************************************************
      * Attempting to get ALL_ACCESS on system processes will fail, so we
      * use different access for signal 0, where we simply want to know
      * if the process is running or not.
      *******************************************************************/
      if(signal == 0){
         hProcess = OpenProcess(
            PROCESS_QUERY_INFORMATION|PROCESS_VM_READ,
            FALSE,
            dwPid
         );
      }
      else{
         hProcess = OpenProcess(
            PROCESS_ALL_ACCESS,
            FALSE,
            dwPid
         );
      }

      switch(signal)
      {
         case 0:
            if(hProcess){
               rb_ary_push(killed_pids,argv[i]);
            }
            else{
               /************************************************************
                * An ACCESS_DENIED error necessarily means that the process
                * is running.  In addition, always assume that PID 0 (System
                * Idle Process) is running.
                *************************************************************/
               if( (GetLastError() == ERROR_ACCESS_DENIED) || (dwPid == 0) ){
                  rb_ary_push(killed_pids,argv[i]);
               }
               else{
                  rb_sys_fail(0);
               }
            }
            break;
         case 1:
            if(GenerateConsoleCtrlEvent(CTRL_C_EVENT,dwPid)){
               rb_ary_push(killed_pids,argv[i]);
            }
            else{
               rb_sys_fail(0);
            }
            break;
         case 2:
            if(GenerateConsoleCtrlEvent(CTRL_BREAK_EVENT,dwPid)){
               rb_ary_push(killed_pids,argv[i]);
            }
            else{
               rb_sys_fail(0);
            }
            break;
         case 9:
            if(TerminateProcess(hProcess,signal)){
               CloseHandle(hProcess);
               rb_ary_push(killed_pids,argv[i]);
		         rb_ary_delete(child_pids,UINT2NUM((DWORD)hProcess));
            }
            else{
               rb_sys_fail(0);
            }
            break;
         default:
            if(hProcess){
               if(os_supported == 1){
                  hThread = CreateRemoteThread(
                     hProcess,
                     NULL,
                     0,
                     (LPTHREAD_START_ROUTINE)(
                        GetProcAddress(
                           GetModuleHandle("KERNEL32.DLL"),"ExitProcess"
                        )
                     ),
                     0,
                     0,
                     &dwThreadId
                  );

                  if(hThread){
                     WaitForSingleObject(hThread, dwTimeout);
                     CloseHandle(hProcess);
                     rb_ary_push(killed_pids,argv[i]);
                  }
                  else{
                     CloseHandle(hProcess);
                     rb_sys_fail(0);
                  }
               }
               else{
                  if(TerminateProcess(hProcess,signal)){
                     CloseHandle(hProcess);
                     rb_ary_push(killed_pids,argv[i]);
  		               rb_ary_delete(child_pids,UINT2NUM((DWORD)hProcess));
                  }
                  else{
                     CloseHandle(hProcess);
                     rb_sys_fail(0);
                  }
               }
            }
            else{
               rb_sys_fail(0);
            }
            break;
      }
   }
   CloseHandle(hProcess);
   return killed_pids;
}

/* Win9x does not support CreateRemoteThread */
int crt_supported()
{
   OSVERSIONINFO OSInfo;
   OSInfo.dwOSVersionInfoSize = sizeof(OSVERSIONINFO);
   GetVersionEx(&OSInfo);

   if(OSInfo.dwPlatformId == VER_PLATFORM_WIN32_NT) // NT, Win2k, XP
   {
      return 1;
   }
   else
   {
      return 0;
   }
}

static VALUE process_fork(VALUE self)
{
    STARTUPINFO si;
    PROCESS_INFORMATION pi;
    VALUE argv;
    int len;
    static int i=-1;
    char buff[1024];

    argv = rb_const_get(rb_cObject,rb_intern("ARGV"));
    len = RARRAY(argv)->len;
    if(len>=2 && strcmp(RSTRING(RARRAY(argv)->ptr[len-2])->ptr,"child")==0) {
      i++;
      if(atoi(RSTRING(RARRAY(argv)->ptr[len-1])->ptr) == i) {
	      if (rb_block_given_p()) {
		    int status;

		    rb_protect(rb_yield, Qundef, &status);
		    ruby_stop(status);
	      }
	      return Qnil;
      } else {
	      return Qfalse;
      }
    }

    sprintf(buff,"ruby \"%s\"",RSTRING(path)->ptr);
    for(i=0;i<len;i++) {
      strcat(buff," ");
      strcat(buff,RSTRING(RARRAY(argv)->ptr[i])->ptr);
    }
    sprintf(buff+strlen(buff)," child %d",RARRAY(child_pids)->len);
    ZeroMemory( &si, sizeof(si) );
    si.cb = sizeof(si);
    ZeroMemory( &pi, sizeof(pi) );

    // Start the child process.
    if( !CreateProcess( NULL, // No module name (use command line).
        buff,             // Command line.
        NULL,             // Process handle not inheritable.
        NULL,             // Thread handle not inheritable.
        TRUE,             // Set handle inheritance to TRUE.
        0,                // No creation flags.
        NULL,             // Use parent's environment block.
        NULL,             // Use parent's starting directory.
        &si,              // Pointer to STARTUPINFO structure.
        &pi )             // Pointer to PROCESS_INFORMATION structure.
    )
    {
        rb_raise(cProcessError,ErrorDescription(GetLastError()));
    }
    rb_ary_push(child_pids,UINT2NUM((DWORD)pi.hProcess));
    return UINT2NUM((DWORD)pi.hProcess);
}

VALUE process_wait(VALUE module)
{
    VALUE pid;
    HANDLE hProcess;
    DWORD dwWait,ExitCode = 0;
    static HANDLE *pids = NULL;
    int i,len = RARRAY(child_pids)->len;

    if(len==0) {
        rb_raise(cProcessError,"No child processes");
    }
	REALLOC_N(pids,HANDLE,len);
	for(i=0;i<len;i++) {
       	pids[i] = (HANDLE)NUM2UINT(RARRAY(child_pids)->ptr[i]);
	}
	dwWait = WaitForMultipleObjects(len,pids,FALSE,INFINITE);
	if(dwWait>=WAIT_OBJECT_0 && dwWait<=WAIT_OBJECT_0+len-1)
	{
		hProcess = pids[dwWait - WAIT_OBJECT_0];
	    GetExitCodeProcess(hProcess,&ExitCode);
	    CloseHandle( hProcess );
	    rb_ary_delete(child_pids,UINT2NUM((DWORD)hProcess));
	    return UINT2NUM((DWORD)hProcess);
	}
    return Qnil;
}

VALUE process_wait2(VALUE module)
{
   VALUE pid;
   HANDLE hProcess;
   DWORD dwWait,ExitCode = 0;
   static HANDLE *pids = NULL;
   int i,len = RARRAY(child_pids)->len;

   if(len==0) {
      rb_raise(cProcessError,"No child processes");
   }
	REALLOC_N(pids,HANDLE,len);
	for(i=0;i<len;i++) {
      pids[i] = (HANDLE)NUM2UINT(RARRAY(child_pids)->ptr[i]);
	}
	dwWait = WaitForMultipleObjects(len,pids,FALSE,INFINITE);
	if(dwWait>=WAIT_OBJECT_0 && dwWait<=WAIT_OBJECT_0+len-1)
	{
		hProcess = pids[dwWait - WAIT_OBJECT_0];
	   GetExitCodeProcess(hProcess,&ExitCode);
	   CloseHandle( hProcess );
	   rb_ary_delete(child_pids,UINT2NUM((DWORD)hProcess));
	   return rb_ary_new3(2,UINT2NUM((DWORD)hProcess),INT2NUM(ExitCode));
	}
   return Qnil;
}

VALUE process_waitpid(int argc, VALUE *argv, VALUE module)
{
   VALUE pid;
   HANDLE hProcess;
   DWORD dwWait,ExitCode = 0;
   static HANDLE *pids = NULL;
   int i,len = RARRAY(child_pids)->len;

   if(len==0) {
      rb_raise(cProcessError,"No child processes");
   }
   if(argc==1 || argc==2) {
	   pid = argv[0];
	   hProcess = (HANDLE)NUM2INT(pid);
	   WaitForSingleObject( hProcess, INFINITE );
	   GetExitCodeProcess(hProcess,&ExitCode);
	   CloseHandle( hProcess );
	   rb_ary_delete(child_pids,pid);
      return UINT2NUM((DWORD)hProcess);
   }
   else {
      rb_raise(rb_eArgError,
         "wrong number of arguments -- waitpid(pid,[option])");
   }

   return Qnil;
}

VALUE process_waitpid2(int argc, VALUE *argv, VALUE module)
{
    VALUE pid;
    HANDLE hProcess;
    DWORD dwWait,ExitCode = 0;
    HANDLE *pids = NULL;
    int i,len = RARRAY(child_pids)->len;
    if(len==0) {
        rb_raise(cProcessError,"No child processes");
    }
    if(argc==1 || argc==2) {
	    pid = argv[0];
	    hProcess = (HANDLE)NUM2INT(pid);
	    WaitForSingleObject( hProcess, INFINITE );
	    GetExitCodeProcess(hProcess,&ExitCode);
	    CloseHandle( hProcess );
	    rb_ary_delete(child_pids,pid);
        return rb_ary_new3(2,UINT2NUM((DWORD)hProcess),INT2NUM(ExitCode));
    }
    else {
        rb_raise(rb_eArgError,
           "wrong number of arguments -- waitpid(pid,[option])");
    }

    return Qnil;
}

VALUE process_get_stderr(VALUE module, VALUE rbArgs){
  VALUE ret;
  char buf[4096];
  int bytes;
  unsigned int ptr = NUM2UINT(rbArgs);
  
  ret = rb_str_new2("");
  while ((bytes = GetStderr(ptr, buf, sizeof(buf))) > 0) {
    ret = rb_str_cat(ret, buf, bytes);
  }
  return ret;
}


VALUE process_get_stdout(VALUE module, VALUE rbArgs){
  VALUE ret;
  char buf[4096];
  int bytes;
  unsigned int ptr = NUM2UINT(rbArgs);
  
  ret = rb_str_new2("");
  while ((bytes = GetStdout(ptr, buf, sizeof(buf))) > 0) {
    ret = rb_str_cat(ret, buf, bytes);
  }
  return ret;
}

VALUE process_is_active(VALUE module, VALUE rbArgs){
  int status;
  unsigned int ptr = NUM2UINT(rbArgs);
  
  status = IsActive(ptr);
  return status ? Qtrue : Qfalse;
}

VALUE process_ctrl_break(VALUE module, VALUE rbArgs){
  unsigned int ptr = NUM2UINT(rbArgs);
  CtrlBreak(ptr);
  return Qnil;
}

VALUE process_ctrl_c(VALUE module, VALUE rbArgs){
  unsigned int ptr = NUM2UINT(rbArgs);
  CtrlC(ptr);
  return Qnil;
}

VALUE process_free(VALUE module, VALUE rbArgs){
  unsigned int ptr = NUM2UINT(rbArgs);
  FreeProcess(ptr);
  return Qnil;
}

VALUE process_create_piped(VALUE module, VALUE rbArgs){
   VALUE rbAppName;
   LPTSTR lpCommandLine;
   void *proc;

   Check_Type(rbArgs,T_HASH);
   rbArgs = normalize(rbArgs);
  
   rbAppName = rb_hash_aref(rbArgs,rb_str_new2("app_name"));
   if(Qnil == rbAppName){
      rb_raise(cProcessError,"app_name must be specified");
   } 
   lpCommandLine = (LPTSTR)StringValuePtr(rbAppName);

   proc = SpawnProcess(lpCommandLine);
 
   return UINT2NUM((unsigned long)proc);

}


VALUE process_create(VALUE module, VALUE rbArgs){
   LPCTSTR lpCurrentDirectory; 
   LPTSTR lpCommandLine;
   BOOL bInheritHandles;
   DWORD dwCreationFlags;
   STARTUPINFO lpStartupInfo;
   PROCESS_INFORMATION lpProcessInformation;
   VALUE rbAppName, rbCmdline, rbInherit, rbFlags, rbCwd, rbTmp;
   
   Check_Type(rbArgs,T_HASH);
   rbArgs = normalize(rbArgs);
  
   rbAppName = rb_hash_aref(rbArgs,rb_str_new2("app_name"));
   if(Qnil == rbAppName){
      rb_raise(cProcessError,"app_name must be specified");
   } 
   lpCommandLine = (LPTSTR)StringValuePtr(rbAppName);

   rbInherit = rb_hash_aref(rbArgs,rb_str_new2("inherit?"));
   if(Qfalse == rbInherit){
      bInheritHandles = FALSE;
   }
   else{
      bInheritHandles = TRUE;
   }
   
   rbFlags = rb_hash_aref(rbArgs,rb_str_new2("creation_flags")) || INT2NUM(0);
   dwCreationFlags = NUM2INT(rbFlags);
   
   rbCwd = rb_hash_aref(rbArgs,rb_str_new2("cwd"));
   if(Qnil == rbCwd){
      lpCurrentDirectory = NULL;
   }
   else{
      lpCurrentDirectory = (LPCTSTR)StringValuePtr(rbCwd);
   }
   
   ZeroMemory(&lpStartupInfo, sizeof(lpStartupInfo));
   lpStartupInfo.cb = sizeof(lpStartupInfo);
   
   // Check for the keys that belong to the StartupInfo struct     
   rbTmp = rb_hash_aref(rbArgs,rb_str_new2("startf_flags"));
   if(Qnil != rbTmp){ lpStartupInfo.dwFlags = NUM2INT(rbTmp); }
   
   rbTmp = rb_hash_aref(rbArgs,rb_str_new2("desktop"));
   if(Qnil != rbTmp){ lpStartupInfo.lpDesktop = (LPTSTR)StringValuePtr(rbTmp); }
   
   rbTmp = rb_hash_aref(rbArgs,rb_str_new2("title"));
   if(Qnil != rbTmp){ lpStartupInfo.lpTitle = (LPTSTR)StringValuePtr(rbTmp); }
   
   rbTmp = rb_hash_aref(rbArgs,rb_str_new2("x"));
   if(Qnil != rbTmp){ lpStartupInfo.dwX = NUM2INT(rbTmp); }
   
   rbTmp = rb_hash_aref(rbArgs,rb_str_new2("y"));
   if(Qnil != rbTmp){ lpStartupInfo.dwY = NUM2INT(rbTmp); }
   
   rbTmp = rb_hash_aref(rbArgs,rb_str_new2("x_size"));
   if(Qnil != rbTmp){ lpStartupInfo.dwXSize = NUM2INT(rbTmp); }
   
   rbTmp = rb_hash_aref(rbArgs,rb_str_new2("y_size"));
   if(Qnil != rbTmp){ lpStartupInfo.dwYSize = NUM2INT(rbTmp); }
   
   rbTmp = rb_hash_aref(rbArgs,rb_str_new2("x_count_chars"));
   if(Qnil != rbTmp){ lpStartupInfo.dwXCountChars = NUM2INT(rbTmp); }
   
   rbTmp = rb_hash_aref(rbArgs,rb_str_new2("y_count_chars"));
   if(Qnil != rbTmp){ lpStartupInfo.dwYCountChars = NUM2INT(rbTmp); }
   
   rbTmp = rb_hash_aref(rbArgs,rb_str_new2("fill_attribute"));
   if(Qnil != rbTmp){ lpStartupInfo.dwFillAttribute = NUM2INT(rbTmp); }
   
   rbTmp = rb_hash_aref(rbArgs,rb_str_new2("sw_flags"));
   if(Qnil != rbTmp){ lpStartupInfo.wShowWindow = NUM2INT(rbTmp); }
      
   ZeroMemory(&lpProcessInformation, sizeof(lpProcessInformation));
   
   if(!CreateProcess(
      NULL,
      lpCommandLine,
      NULL,
      NULL,
      bInheritHandles,
      dwCreationFlags,
      NULL,
      lpCurrentDirectory,
      &lpStartupInfo,
      &lpProcessInformation
   )){
      rb_raise(cProcessError,ErrorDescription(GetLastError())); 
   }
   
   return UINT2NUM(lpProcessInformation.dwProcessId);
}

void Init_process()
{
   child_pids = rb_ary_new();

   /* Does platform support CreateRemoteThread? */
   os_supported = crt_supported();
   fname = rb_gv_get("$0");
   path = rb_file_s_expand_path(1, &fname);

   /* Classes */
   cProcessError = rb_define_class_under(rb_mProcess,"Win32::ProcessError",
      rb_eRuntimeError);

   /* Class Methods */
   rb_define_singleton_method(rb_mProcess,"fork", process_fork, 0);
   rb_define_module_function(rb_mProcess,"kill",process_kill,-1); 
   rb_define_module_function(rb_mProcess,"wait", process_wait, 0);
   rb_define_module_function(rb_mProcess,"wait2", process_wait2, 0);
   rb_define_module_function(rb_mProcess,"waitpid", process_waitpid, -1);
   rb_define_module_function(rb_mProcess,"waitpid2", process_waitpid2, -1);
   rb_define_module_function(rb_mProcess,"create",process_create,1);
   rb_define_module_function(rb_mProcess,"create_piped",process_create_piped,1);
   rb_define_module_function(rb_mProcess,"is_active",process_is_active,1);
   rb_define_module_function(rb_mProcess,"get_stdout",process_get_stdout,1);
   rb_define_module_function(rb_mProcess,"get_stderr",process_get_stderr,1);
   rb_define_module_function(rb_mProcess,"free",process_free,1);
   rb_define_module_function(rb_mProcess,"ctrl_break",process_ctrl_break,1);
   rb_define_module_function(rb_mProcess,"ctrl_c",process_ctrl_c,1);
   
   rb_define_global_function("fork", process_fork, 0);
   
   /* Constants */
   rb_define_const(rb_mProcess,"VERSION",rb_str_new2(WIN32_PROCESS_VERSION));
   set_constants(rb_mProcess);
}

