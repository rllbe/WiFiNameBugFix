#include <mach/mach.h>
#include <mach/vm_map.h>
#include <substrate.h>

kern_return_t get_vm_protection_64(mach_port_t port, vm_address_t address, vm_prot_t *outprot) {
    vm_size_t size;
    vm_region_basic_info_data_t info;
    memory_object_name_t object;
    mach_msg_type_number_t info_count = VM_REGION_BASIC_INFO_COUNT_64;
    kern_return_t err = vm_region_64(port, &address, &size, VM_REGION_BASIC_INFO_64, (vm_region_info_t)&info, &info_count, &object);
    if (err == KERN_SUCCESS && outprot) *outprot = info.protection;
    return err;
}

void (*orig_WFLogger__WFLog_message_)(id, SEL, int, char *, ...);
void mod_WFLogger__WFLog_message_(id self, SEL _cmd, int level, char *message, ...) {
    if (!message || !strlen(message)) {
        orig_WFLogger__WFLog_message_(self, _cmd, level, "(null)");
        return;
    }
    
    va_list ap;
    va_start(ap, message);
    for (char *ptr = message; *ptr != '\0'; ptr++) {
        if (*ptr != '%') continue;
        ptr++;
        if (*ptr != '@' && *ptr != 's' && *ptr != 'p' && *ptr != 'n') continue;
        void *arg = va_arg(ap, void *);
        if ((uint64_t)arg > 0xFFFFFFFF) {
            vm_prot_t prot;
            kern_return_t err = get_vm_protection_64(mach_task_self(), (vm_address_t)arg, &prot);
            if (err == KERN_SUCCESS && prot & VM_PROT_READ) continue;
        }
        orig_WFLogger__WFLog_message_(self, _cmd, level, (char *)[@(message) stringByReplacingOccurrencesOfString:@"%" withString:@"%%"].UTF8String);
        return;
    }
    va_end(ap);
    
    va_list arg;
    va_start(arg, message);
    NSString *formatted = [[NSString alloc] initWithFormat:@(message) locale:0 arguments:arg];
    va_end(arg);
    orig_WFLogger__WFLog_message_(self, _cmd, level, (char *)[formatted stringByReplacingOccurrencesOfString:@"%" withString:@"%%"].UTF8String);
    [formatted release];
}

%ctor {
    MSHookMessageEx(%c(WFLogger), @selector(WFLog:message:), (IMP)&mod_WFLogger__WFLog_message_, (IMP *)&orig_WFLogger__WFLog_message_);
}
