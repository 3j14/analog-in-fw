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
  int fd;
  volatile uint8_t *flags;
  volatile void *cfg, *status;
  volatile uint64_t *if_0;
  volatile int16_t *ram;
  uint32_t size;
  int16_t value[2];

  if ((fd = open("/dev/mem", O_RDWR)) < 0) {
    perror("open");
    return EXIT_FAILURE;
  }

  cfg = mmap(NULL, sysconf(_SC_PAGESIZE), PROT_READ | PROT_WRITE, MAP_SHARED,
             fd, 0x40000000);

  status = mmap(NULL, sysconf(_SC_PAGESIZE), PROT_READ | PROT_WRITE, MAP_SHARED,
                fd, 0x41000000);
  if_0 =
      mmap(NULL, sysconf(_SC_PAGESIZE), PROT_WRITE, MAP_SHARED, fd, 0x42000000);
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
  uint16_t *write_count = (uint16_t *)(status + 0);
  uint16_t *read_count = (uint16_t *)(status + 2);
  sleep(1);

  uint64_t i = 0;
  while (1) {
    *if_0 = (i++);
    printf("write: %d\n", *write_count);
    printf("read: %d\n", *read_count);
    sleep(1);
  }
  return EXIT_SUCCESS;
}
