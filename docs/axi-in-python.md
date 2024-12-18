# Write to AXI from user space in Python

You can use [`mmap`](https://docs.python.org/3/library/mmap.html) to write to AXI
registers from the PS into PL in Linux user space:

```python
import ctypes
import mmap
import os

page_size = os.sysconf("SC_PAGESIZE")
fd = os.open("/dev/mem", os.O_RDWR)
mem = mmap.mmap(fd, page_size, access=mmap.ACCESS_WRITE, offset=0x4000_0000)

config = ctypes.c_uint8.from_buffer(mem, 0)
config.value = 255  # write 0b11111111 to the config register

# Status address is offset by 0x4 (hex)
status = ctypes.c_uint32.from_buffer(mem, 0x4)
print("Status: ", status.value)
```
