#include <stdio.h>
#include <inttypes.h>

#define FIRST_BIT 0x8000000000000000 // 1 and 63 zeros

// Assumes little endian
void printBits(size_t const size, void const * const ptr)
{
    unsigned char *b = (unsigned char*) ptr;
    unsigned char byte;
    int i, j;
    
    for (i = size-1; i >= 0; i--) {
        for (j = 7; j >= 0; j--) {
            byte = (b[i] >> j) & 1;
            printf("%u", byte);
        }
    }
    puts("");
}

typedef struct {
    uint64_t lo;
    uint64_t hi;
} uint128_t;

int64_t mdiv(int64_t *x, int64_t n, int64_t y);


int main() {
    int64_t n = 1;
    int64_t x[1] = {1};
    int64_t y = -1;
    //printf("%" PRIu64 "\n", x);
    int64_t r = mdiv(x, n, y);
    
    printf("Po dzieleniu: ");
    for (int i = 0; i < n; i++) {
        printf("0x%016" PRIx64 " ", x[i]);
    }
    printf("Reszta: ");  printf("0x%016" PRIx64 "\n", r);

    return 0;
}