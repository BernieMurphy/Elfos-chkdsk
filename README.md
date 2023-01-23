Chkdsk is a program that displays various statistics regarding an1802 Elf-OS disk.
Sample output for a two disk system is shown below. Note that this program will
hang with earlier versions of Elf-OS if a disk is not present. Unlike the DOS
version of chkdsk, the current version of this program does not detect file 
system anomolies such as orphaned sectors.

  chkdsk
  
  Disk 0:
  
  Type 1 filesystem
  
  Sector 0 checksum: BA93
  
  Source disk is 240 MB. Now scanning AUs ...
  
  1 MB is in use.
  
  Total AUs: 61440
  
  Free  AUs: 61207
  
  

  Disk 1:
  Type 1 filesystem
  Sector 0 checksum: BA93
  Source disk is 240 MB. Now scanning AUs ...
  2 MB is in use.
  Total AUs: 61440
  Free  AUs: 61177
  
  Ready
  :
