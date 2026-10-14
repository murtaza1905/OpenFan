#include "smc.h"

#include <IOKit/IOKitLib.h>
#include <string.h>

#define KERNEL_INDEX_SMC 2

#define SMC_CMD_READ_BYTES   5
#define SMC_CMD_WRITE_BYTES  6
#define SMC_CMD_READ_INDEX   8
#define SMC_CMD_READ_KEYINFO 9

#define SMC_RESULT_KEY_NOT_FOUND 0x84

typedef struct {
    uint8_t  major;
    uint8_t  minor;
    uint8_t  build;
    uint8_t  reserved;
    uint16_t release;
} smc_version_t;

typedef struct {
    uint16_t version;
    uint16_t length;
    uint32_t cpuPLimit;
    uint32_t gpuPLimit;
    uint32_t memPLimit;
} smc_plimit_t;

typedef struct {
    uint32_t dataSize;
    uint32_t dataType;
    uint8_t  dataAttributes;
} smc_keyinfo_t;

typedef struct {
    uint32_t      key;
    smc_version_t vers;
    smc_plimit_t  pLimitData;
    smc_keyinfo_t keyInfo;
    uint8_t       result;
    uint8_t       status;
    uint8_t       data8;
    uint32_t      data32;
    uint8_t       bytes[32];
} smc_keydata_t;

static io_connect_t g_connection = 0;

static uint32_t key_to_u32(const char *key) {
    uint32_t value = 0;
    for (int i = 0; i < 4; i++) {
        value = (value << 8) | (uint8_t)key[i];
    }
    return value;
}

static void u32_to_key(uint32_t value, char out[5]) {
    out[0] = (char)((value >> 24) & 0xFF);
    out[1] = (char)((value >> 16) & 0xFF);
    out[2] = (char)((value >> 8) & 0xFF);
    out[3] = (char)(value & 0xFF);
    out[4] = '\0';
}

int smc_open(void) {
    if (g_connection != 0) {
        return 0;
    }
    io_service_t service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"));
    if (service == 0) {
        return -1;
    }
    kern_return_t kr = IOServiceOpen(service, mach_task_self(), 0, &g_connection);
    IOObjectRelease(service);
    if (kr != KERN_SUCCESS) {
        g_connection = 0;
        return (int)kr;
    }
    return 0;
}

void smc_close(void) {
    if (g_connection != 0) {
        IOServiceClose(g_connection);
        g_connection = 0;
    }
}

static int smc_call(smc_keydata_t *input, smc_keydata_t *output) {
    if (g_connection == 0) {
        int r = smc_open();
        if (r != 0) {
            return r;
        }
    }
    size_t outputSize = sizeof(smc_keydata_t);
    kern_return_t kr = IOConnectCallStructMethod(g_connection,
                                                 KERNEL_INDEX_SMC,
                                                 input, sizeof(smc_keydata_t),
                                                 output, &outputSize);
    if (kr != KERN_SUCCESS) {
        return (int)kr;
    }
    if (output->result != 0) {
        return 1000 + output->result;
    }
    return 0;
}

int smc_key_info(const char *key, char type_out[5], uint32_t *size_out) {
    smc_keydata_t input;
    smc_keydata_t output;
    memset(&input, 0, sizeof(input));
    memset(&output, 0, sizeof(output));

    input.key = key_to_u32(key);
    input.data8 = SMC_CMD_READ_KEYINFO;

    int r = smc_call(&input, &output);
    if (r != 0) {
        return r;
    }
    u32_to_key(output.keyInfo.dataType, type_out);
    *size_out = output.keyInfo.dataSize;
    return 0;
}

int smc_read(const char *key, smc_value_t *out) {
    memset(out, 0, sizeof(*out));

    char type[5];
    uint32_t size = 0;
    int r = smc_key_info(key, type, &size);
    if (r != 0) {
        return r;
    }
    if (size > 32) {
        return -2;
    }

    smc_keydata_t input;
    smc_keydata_t output;
    memset(&input, 0, sizeof(input));
    memset(&output, 0, sizeof(output));

    input.key = key_to_u32(key);
    input.keyInfo.dataSize = size;
    input.data8 = SMC_CMD_READ_BYTES;

    r = smc_call(&input, &output);
    if (r != 0) {
        return r;
    }

    memcpy(out->key, key, 4);
    out->key[4] = '\0';
    memcpy(out->type, type, 5);
    out->size = size;
    memcpy(out->bytes, output.bytes, size);
    return 0;
}

int smc_write(const char *key, const uint8_t *bytes, uint32_t size) {
    char type[5];
    uint32_t keySize = 0;
    int r = smc_key_info(key, type, &keySize);
    if (r != 0) {
        return r;
    }
    if (size != keySize || size > 32) {
        return -3;
    }

    smc_keydata_t input;
    smc_keydata_t output;
    memset(&input, 0, sizeof(input));
    memset(&output, 0, sizeof(output));

    input.key = key_to_u32(key);
    input.keyInfo.dataSize = size;
    input.data8 = SMC_CMD_WRITE_BYTES;
    memcpy(input.bytes, bytes, size);

    return smc_call(&input, &output);
}

int smc_key_count(uint32_t *count) {
    smc_value_t value;
    int r = smc_read("#KEY", &value);
    if (r != 0) {
        return r;
    }
    if (value.size != 4) {
        return -4;
    }
    *count = ((uint32_t)value.bytes[0] << 24) |
             ((uint32_t)value.bytes[1] << 16) |
             ((uint32_t)value.bytes[2] << 8) |
             ((uint32_t)value.bytes[3]);
    return 0;
}

int smc_key_at_index(uint32_t index, char key_out[5]) {
    smc_keydata_t input;
    smc_keydata_t output;
    memset(&input, 0, sizeof(input));
    memset(&output, 0, sizeof(output));

    input.data8 = SMC_CMD_READ_INDEX;
    input.data32 = index;

    int r = smc_call(&input, &output);
    if (r != 0) {
        return r;
    }
    u32_to_key(output.key, key_out);
    return 0;
}
