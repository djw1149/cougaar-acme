#define WIN32_PROCESS_VERSION "0.3.0"
#define ERROR_BUFFER 512

// List of valid keys for the Process.create() method
char* create_keys[] = {
   "app_name",
   "create_flags",
   "inherited?",
   "creation_flags",
   "cwd",
   "environment",
   "desktop",
   "title",
   "x",
   "y",
   "x_size",
   "y_size",
   "x_count_chars",
   "y_count_chars",
   "fill_attribute",
   "startf_flags",
   "sw_flags"
};

// Convert a Ruby symbol to a Ruby string
static VALUE rb_sym2str(VALUE sym)
{
   char* temp;
   ID id = SYM2ID(sym);
   temp = rb_id2name(id);
   return rb_str_new2(temp);
}

// Validate any hash keys passed to the create() method.
void validate_key(VALUE rbStr){
   int n;
   int found = 0;
   int size = sizeof(create_keys) / sizeof(create_keys[0]);
   char* string = StringValuePtr(rbStr);
   for(n = 0; n < size; n++){
      if(0 == strcmp(create_keys[n],string)){
         found = 1;
      }
   }
   // If the key wasn't found, raise an ArgumentError;
   if(0 == found){
      char err[ERROR_BUFFER];
      sprintf(err,"key '%s' is not valid",string);
      rb_raise(rb_eArgError,err);
   }
}

// Convert symbols to strings and verify keys
static VALUE normalize(VALUE rbHash){
   VALUE keys = rb_funcall(rbHash,rb_intern("keys"),0);
   VALUE vals = rb_funcall(rbHash,rb_intern("values"),0);
   int len = RARRAY(keys)->len;
   VALUE rbVal;
   int n;
   
   for(n = 0; n < len; n++){
      rbVal = rb_ary_entry(keys,n);
      if(T_SYMBOL == TYPE(rbVal)){
         rbVal = rb_sym2str(rbVal);
      }
      validate_key(rbVal);   
      rb_hash_aset(rbHash,rbVal,rb_ary_entry(vals,n));      
   }

   return rbHash;
}

void set_constants(VALUE module){
   // Process creation constants
#ifdef CREATE_BREAKAWAY_FROM_JOB
   rb_define_const(module,"CREATE_BREAKAWAY_FROM_JOB",
      INT2NUM(CREATE_BREAKAWAY_FROM_JOB));
#endif
   rb_define_const(module,"CREATE_DEFAULT_ERROR_MODE",
      INT2NUM(CREATE_DEFAULT_ERROR_MODE));
   rb_define_const(module,"CREATE_NEW_CONSOLE",
      INT2NUM(CREATE_NEW_CONSOLE));
   rb_define_const(module,"CREATE_NEW_PROCESS_GROUP",
      INT2NUM(CREATE_NEW_PROCESS_GROUP));
   rb_define_const(module,"CREATE_NO_WINDOW",
      INT2NUM(CREATE_NO_WINDOW));
#ifdef CREATE_PRESERVE_CODE_AUTHZ_LEVEL
   rb_define_const(module,"CREATE_PRESERVE_CODE_AUTHZ_LEVEL",
      INT2NUM(CREATE_PRESERVE_CODE_AUTHZ_LEVEL));
#endif
   rb_define_const(module,"CREATE_SEPARATE_WOW_VDM",
      INT2NUM(CREATE_SEPARATE_WOW_VDM));
   rb_define_const(module,"CREATE_SHARED_WOW_VDM",
      INT2NUM(CREATE_SHARED_WOW_VDM));
   rb_define_const(module,"CREATE_SUSPENDED",
      INT2NUM(CREATE_SUSPENDED));
   rb_define_const(module,"CREATE_UNICODE_ENVIRONMENT",
      INT2NUM(CREATE_UNICODE_ENVIRONMENT));
   rb_define_const(module,"DEBUG_ONLY_THIS_PROCESS",
      INT2NUM(DEBUG_ONLY_THIS_PROCESS));
   rb_define_const(module,"DEBUG_PROCESS",
      INT2NUM(DEBUG_PROCESS));
   rb_define_const(module,"DETACHED_PROCESS",
      INT2NUM(DETACHED_PROCESS));
      
   // Process priority constants
#ifdef ABOVE_NORMAL_PRIORITY_CLASS
   rb_define_const(module,"ABOVE_NORMAL",INT2NUM(ABOVE_NORMAL_PRIORITY_CLASS));
   rb_define_const(module,"BELOW_NORMAL",INT2NUM(BELOW_NORMAL_PRIORITY_CLASS));
#endif
   rb_define_const(module,"HIGH",INT2NUM(HIGH_PRIORITY_CLASS));
   rb_define_const(module,"IDLE",INT2NUM(IDLE_PRIORITY_CLASS));
   rb_define_const(module,"NORMAL",INT2NUM(NORMAL_PRIORITY_CLASS));
   rb_define_const(module,"REALTIME",INT2NUM(REALTIME_PRIORITY_CLASS));
   
   // Fill attributes (for console windows)
   rb_define_const(module,"FOREGROUND_BLUE",INT2NUM(FOREGROUND_BLUE));
   rb_define_const(module,"FOREGROUND_GREEN",INT2NUM(FOREGROUND_GREEN));
   rb_define_const(module,"FOREGROUND_RED",INT2NUM(FOREGROUND_RED));
   rb_define_const(module,"FOREGROUND_INTENSITY",INT2NUM(FOREGROUND_INTENSITY));
   rb_define_const(module,"BACKGROUND_BLUE",INT2NUM(FOREGROUND_BLUE));
   rb_define_const(module,"BACKGROUND_GREEN",INT2NUM(BACKGROUND_GREEN));
   rb_define_const(module,"BACKGROUND_RED",INT2NUM(BACKGROUND_RED));
   rb_define_const(module,"BACKGROUND_INTENSITY",INT2NUM(BACKGROUND_INTENSITY));
   
   // Flags (for console windows)
   rb_define_const(module,"FORCEONFEEDBACK",INT2NUM(STARTF_FORCEONFEEDBACK));
   rb_define_const(module,"FORCEOFFFEEDBACK",INT2NUM(STARTF_FORCEOFFFEEDBACK));
   rb_define_const(module,"RUNFULLSCREEN",INT2NUM(STARTF_RUNFULLSCREEN));
   rb_define_const(module,"USECOUNTCHARS",INT2NUM(STARTF_USECOUNTCHARS));
   rb_define_const(module,"USEFILLATTRIBUTE",INT2NUM(STARTF_USEFILLATTRIBUTE));
   rb_define_const(module,"USEPOSITION",INT2NUM(STARTF_USEPOSITION));
   rb_define_const(module,"USESHOWWINDOW",INT2NUM(STARTF_USESHOWWINDOW));
   rb_define_const(module,"USESIZE",INT2NUM(STARTF_USESIZE));
   rb_define_const(module,"USESTDHANDLES",INT2NUM(STARTF_USESTDHANDLES));
   
   // Show Window constants
   rb_define_const(module,"SW_HIDE",INT2NUM(SW_HIDE));
   rb_define_const(module,"SW_SHOWNORMAL",INT2NUM(SW_SHOWNORMAL));
   rb_define_const(module,"SW_NORMAL",INT2NUM(SW_NORMAL));
   rb_define_const(module,"SW_SHOWMINIMIZED",INT2NUM(SW_SHOWMINIMIZED));
   rb_define_const(module,"SW_SHOWMAXIMIZED",INT2NUM(SW_SHOWMAXIMIZED));
   rb_define_const(module,"SW_MAXIMIZE",INT2NUM(SW_MAXIMIZE));
   rb_define_const(module,"SW_SHOWNOACTIVATE",INT2NUM(SW_SHOWNOACTIVATE));
   rb_define_const(module,"SW_SHOW",INT2NUM(SW_SHOW));
   rb_define_const(module,"SW_MINIMIZE",INT2NUM(SW_MINIMIZE));
   rb_define_const(module,"SW_SHOWMINNOACTIVE",INT2NUM(SW_SHOWMINNOACTIVE));
   rb_define_const(module,"SW_SHOWNA",INT2NUM(SW_SHOWNA));
   rb_define_const(module,"SW_RESTORE",INT2NUM(SW_RESTORE));
   rb_define_const(module,"SW_SHOWDEFAULT",INT2NUM(SW_SHOWDEFAULT));
   rb_define_const(module,"SW_FORCEMINIMIZE",INT2NUM(SW_FORCEMINIMIZE));
   rb_define_const(module,"SW_MAX",INT2NUM(SW_MAX));
}

// Return an error code as a string
LPTSTR ErrorDescription(DWORD p_dwError)
{
   HLOCAL hLocal = NULL;
   static char ErrStr[1024];
   int len;

   if (!(len=FormatMessage(
      FORMAT_MESSAGE_ALLOCATE_BUFFER |
      FORMAT_MESSAGE_FROM_SYSTEM |
      FORMAT_MESSAGE_IGNORE_INSERTS,
      NULL,
      p_dwError,
      MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT), // Default language
      (LPTSTR)&hLocal,
      0,
      NULL)))
   {
      rb_raise(rb_eStandardError,"Unable to format error");
   }
   memset(ErrStr,0,1024);
   strncpy(ErrStr,(LPTSTR)hLocal,len-2); // remove \r\n
   LocalFree(hLocal);
   return ErrStr;
}

extern void *SpawnProcess(char *cmdline) ;
extern int IsActive(DWORD proc);
extern int GetStderr(DWORD proc, char *buf, int size);
extern int GetStdout(DWORD proc, char *buf, int size);
extern void CtrlBreak(DWORD proc);
extern void CtrlC(DWORD proc);
extern void FreeProcess(DWORD proc);

