#include <assert.h>
#include <inttypes.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define SIZE(x) (sizeof x / sizeof x[0])

// This is the declaration of the assembler function
int64_t mdiv(int64_t *x, size_t n, int64_t y);

// This structure stores test data and expected result
typedef struct {
  size_t  const  n; // dividend size
  int64_t const *x; // dividend
  int64_t const  y; // divisor
  int64_t const *z; // expected quotient
  int64_t const  r; // expected remainder
} test_data_t;

// Example test data
static const test_data_t test_data[] = {
  {1, (int64_t[1]){ 13},  5, (int64_t[1]){ 2},  3},
  {1, (int64_t[1]){-13},  5, (int64_t[1]){-2}, -3},
  {1, (int64_t[1]){ 13}, -5, (int64_t[1]){-2},  3},
  {1, (int64_t[1]){-13}, -5, (int64_t[1]){ 2}, -3},
  {2, (int64_t[2]){0,  13},  5, (int64_t[2]){0x9999999999999999,  2},  3},
  {2, (int64_t[2]){0, -13},  5, (int64_t[2]){0x6666666666666667, -3}, -3},
  {2, (int64_t[2]){0,  13}, -5, (int64_t[2]){0x6666666666666667, -3},  3},
  {2, (int64_t[2]){0, -13}, -5, (int64_t[2]){0x9999999999999999,  2}, -3},
  {3, (int64_t[3]){1, 1, 1}, 2, (int64_t[3]){0x8000000000000000, 0x8000000000000000, 0},  1},
};

int main() {
  for (size_t test = 0; test < SIZE(test_data); ++test) {
    size_t n = test_data[test].n;
    int64_t *work_space = malloc(n * sizeof (int64_t));
    assert(work_space);
    memcpy(work_space, test_data[test].x, n * sizeof (int64_t));

    int64_t r = mdiv(work_space, n, test_data[test].y);

    bool pass = true;
    if (r != test_data[test].r) {
      pass = false;
      printf("In test %zu remainder\n"
             "is        %" PRIi64 ",\n"
             "should be %" PRIi64 ".\n",
             test, r, test_data[test].r);
    }
    for (size_t i = 0; i < n; ++i) {
      if (work_space[i] != test_data[test].z[i]) {
        pass = false;
        printf("In test %zu in quotient under index %zu\n"
               "there is    0x%016" PRIx64 ",\n"
               "should be   0x%016" PRIx64 ".\n",
               test, i, work_space[i], test_data[test].z[i]);
      }
    }
    free(work_space);

    if (pass) {
      printf("Test %zu was successful.\n", test);
    }
  }
}
