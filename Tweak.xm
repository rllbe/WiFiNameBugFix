#include <mach/mach.h>
#include <mach/vm_map.h>
#include <notify.h>
#include <substrate.h>

bool enable_log = false;

kern_return_t get_vm_protection_64(mach_port_t port, vm_address_t address, vm_prot_t *outprot) {
    if (address <= 0xFFFFFFFF) return KERN_INVALID_ADDRESS;
    vm_size_t size;
    vm_region_basic_info_data_t info;
    memory_object_name_t object;
    mach_msg_type_number_t info_count = VM_REGION_BASIC_INFO_COUNT_64;
    kern_return_t err = vm_region_64(port, &address, &size, VM_REGION_BASIC_INFO_64, (vm_region_info_t)&info, &info_count, &object);
    if (err == KERN_SUCCESS && outprot) *outprot = info.protection;
    return err;
}

int get_char_type(char c) {
    char p, *pp = "psS@";
    while ((p = *(pp++))) if (c == p) return 3;
    pp = "*acdefginouxACDEFGOUX";
    while ((p = *(pp++))) if (c == p) return 2;
    pp = " .-+#$0123456789hjlqtzL";
    while ((p = *(pp++))) if (c == p) return 1;
    return 0;
}

bool check_format_with_arguments(char *format, va_list ap) {
    bool is_flag = false;
    void *arg;
    vm_prot_t prot;
    for (char *ptr = format; *ptr != '\0'; ptr++) {
        if (*ptr == '%') {
            is_flag = !is_flag;
            continue;
        }
        if (!is_flag) continue;
        int char_type = get_char_type(*ptr);
        switch (char_type) {
            case 3:
                arg = va_arg(ap, void *);
                is_flag = false;
                if (get_vm_protection_64(mach_task_self(), (vm_address_t)arg, &prot) == KERN_SUCCESS && prot & VM_PROT_READ) continue;
                return false;
            case 1:
                if (*ptr == '$') return false;
                continue;
            case 2:
                arg = va_arg(ap, void *);
            case 0:
                is_flag = false;
                continue;
        }
    }
    return true;
}

void (*orig_WFLogger__WFLog_message_)(id, SEL, int, char *, ...);
void mod_WFLogger__WFLog_message_(id self, SEL _cmd, int level, char *message, ...) {
    if (!enable_log) return;
    if (!message || !strlen(message)) {
        orig_WFLogger__WFLog_message_(self, _cmd, level, "(null)");
        return;
    }
    
    va_list ap;
    va_start(ap, message);
    if (!check_format_with_arguments(message, ap)) {
        orig_WFLogger__WFLog_message_(self, _cmd, level, "%s", message);
        return;
    }
    va_end(ap);
    
    va_start(ap, message);
    NSString *formatted = [[NSString alloc] initWithFormat:@(message) locale:0 arguments:ap];
    va_end(ap);
    orig_WFLogger__WFLog_message_(self, _cmd, level, "%@", formatted);
    [formatted release];
}

%ctor {
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:@"/private/var/mobile/Library/Preferences/in.net.mario.tweak.wfloggerfixprefs.plist"];
    if (prefs) {
        NSValue *value = [prefs objectForKey:@"enablelog"];
        if (value) enable_log = [value boolValue];
    }
    
    MSHookMessageEx(%c(WFLogger), @selector(WFLog:message:), (IMP)&mod_WFLogger__WFLog_message_, (IMP *)&orig_WFLogger__WFLog_message_);
}
