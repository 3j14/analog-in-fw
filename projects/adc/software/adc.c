// Based on adc_recorder.c, copyright (c) Pavel Deminm, licensed under
// the MIT License (MIT).

#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <unistd.h>

#define CMA_ALLOC _IOWR('Z', 0, uint32_t)

int main() {
  int fd, i;
  volatile uint8_t *flags;
  volatile void *cfg;
  volatile int16_t *ram;
  uint32_t size;
  int16_t value[2];

  if ((fd = open("/dev/mem", O_RDWR)) < 0) {
    perror("open");
    return EXIT_FAILURE;
  }

  cfg = mmap(NULL, sysconf(_SC_PAGESIZE), PROT_READ | PROT_WRITE, MAP_SHARED,
             fd, 0x40000000);

  close(fd);

  if ((fd = open("/dev/cma", O_RDWR)) < 0) {
    perror("open");
    return EXIT_FAILURE;
  }

  size = 1024 * sysconf(_SC_PAGESIZE);

  if (ioctl(fd, CMA_ALLOC, &size) < 0) {
    perror("ioctl");
    return EXIT_FAILURE;
  }

  ram = mmap(NULL, 1024 * sysconf(_SC_PAGESIZE), PROT_READ | PROT_WRITE,
             MAP_SHARED, fd, 0);

  // Reset and Enable registers
  flags = (uint8_t *)(cfg + 0);
  *flags = 0b11111111;
  sleep(1);

  return EXIT_SUCCESS;
}
