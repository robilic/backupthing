# BackupThing

Backup and restore tool.

### Running a Backup

Use either client.py, or the VB client (Windows only)

### Restore Script

Usage:

*python restore.py -client JeffB-laptop -catalog Dec2019Backup -restoreto F:\Documents -match Iventory.xlsx*

## How it works

Very loosely based on a talk Dropbox gave. It stores files, split into blocks of length BLOCK_SIZE (currently 4MB), and keeps catalogs of each clients backup jobs.

![File Layout](/images/dropboxfileformat1.png)

There is an  HTTP server which has two methods:

### /COMMIT

![First Commit](/images/protocol11.png)

The client should first attempt to 'commit' a file to the server. Post JSON data containing:

| Key | Value |
| -----| ----- |
| Client | 'JOE_LAPTOP' |
| Catalog | 'June01Backup' |
| FileInfo | 'C:\Foo\Bar.txt', mtime, ctime, size |
| Commit | Block_1_ID, Block_1_hash, Block_2_ID, Block_2_hash, ... Block_x_ID, Block_x_hash |

The server will then return the list of Block ID's that it needs to be able to commit the file. These are the blocks it does not have stored. Blocks can be shared across clients and catalogs. If the server has all the blocks that make up the file attempting to be committed, it will return 'OK' and create an entry in that client's catalog file for that particular backup.

### /STORE

This method stores a block, up to BLOCK_SIZE in length. Post JSON data containing:

| Key | Value |
| -----| ----- |
| Hash | MD5 of the block |
| File | File of the block data |

The server will return 'OK' upon receiving the block, checking the hash, and storing the block. Block are stored by using the first 4 characters of the hash to create sub-directories.

Therefore, a file with the hash of `6a204bd89f3c8348afd5c77c717a097a` would be stored in the following path:

`6\a\2\0\4bd89f3c8348afd5c77c717a097a`

![Store Blocks](/images/protocol21.png)

Typically, the client will request a commit, and then STORE all the blocks the server is missing, and then perform another COMMIT of that file which will then save it to the catalog.

![Final Commit](/images/protocol31.png)
