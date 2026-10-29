#ifndef MASTER_STACK_H
#define MASTER_STACK_H
#include <stdint.h>
#include <stdbool.h>
#define MS_MAGIC 0x4D535431
#define MS_SMALL_RING_SIZE 1024
#define MS_ARENA_SIZE 61440
typedef enum { MS_OK=0, MS_ERR_OOM=100, MS_ERR_BAD_SIG=302 } MsErrorCode;
typedef struct { MsErrorCode code; uint32_t layer_origin; char msg[128]; } MsError;
typedef struct { uint32_t magic; uint16_t version; uint16_t payload_len; uint16_t seq; } MsHeader;
typedef struct { uint8_t buf[1024]; MsHeader descs[16]; } SmallRing;
MsError ms_small_ring_init(SmallRing* ring);
bool ms_small_ring_pop(SmallRing* ring, uint8_t layer_id, MsHeader* out_hdr, uint8_t** out_payload);
MsError ms_verify_signature(const uint8_t* pubkey_32, const uint8_t* msg, size_t len, const uint8_t* sig_64);
#endif
