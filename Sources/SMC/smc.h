#ifndef OPENFAN_SMC_H
#define OPENFAN_SMC_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    char key[5];
    char type[5];
    uint32_t size;
    uint8_t bytes[32];
} smc_value_t;

int smc_open(void);
void smc_close(void);

int smc_key_info(const char *key, char type_out[5], uint32_t *size_out);
int smc_read(const char *key, smc_value_t *out);
int smc_write(const char *key, const uint8_t *bytes, uint32_t size);

int smc_key_count(uint32_t *count);
int smc_key_at_index(uint32_t index, char key_out[5]);

#define SMC_ERR_KEY_NOT_FOUND 1132

#ifdef __cplusplus
}
#endif

#endif
