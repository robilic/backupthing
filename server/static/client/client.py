import hashlib
import os
import sqlite3
import requests
import json
import socket
import datetime

KB = 1024
MB = 1024 * KB
BLOCK_SIZE = 4 * MB

CLIENT_NAME = socket.gethostname()
CATALOG_NAME = datetime.datetime.now().strftime('%Y%m%d%H%M%S')

#SERVER_ADDRESS = 'http://A-IS-ROBERTV:8080'
SERVER_ADDRESS = 'http://127.0.0.1:8080'
#SERVER_ADDRESS = 'http://httpbin.org'

def md5(fname):
    hash_md5 = hashlib.md5()
    with open(fname, "rb") as f:
        for block in iter(lambda: f.read(4096), b""):
            hash_md5.update(block)
    return hash_md5.hexdigest()


# send single block function
def send_block(block_data):
    h = hashlib.md5()
    h.update(block_data)
    #print('send_block(): hash: ' + h.hexdigest())
    #print('block head: ' + block_data[0:20].hex())
    r = requests.post(SERVER_ADDRESS + '/store/', data = { 'hash': h.hexdigest() }, files={ 'file': ('data', block_data) })
    return r

# split file into blocks/hashes, attempt commit to server
def commit(f):
    fi = os.stat(f)
    file_info = { 'filename': f, 'mtime': fi.st_mtime, 'ctime': fi.st_ctime, 'size': fi.st_size }
    fp = open(f, 'rb')
    done = False
    block_count = 1
    block_info = []
    while not done:
        block = fp.read(BLOCK_SIZE)
        if not block:
            done = True
        else:
            h = hashlib.md5()
            h.update(block)
            block_info.append({ 'id': block_count, 'hash': h.hexdigest() })
            block_count = block_count + 1

    r = requests.post(SERVER_ADDRESS + '/commit/', json={   'client': CLIENT_NAME,
                                                            'catalog': CATALOG_NAME,
                                                            'commit': block_info,
                                                            'fileinfo': file_info })
    return r

# now that we know what blocks to send, go through file sending needed blocks
def send_file(f, needed_blocks):
    fp = open(f, 'rb')
    done = False
    block_count = 1
    while not done:
        block_data = fp.read(BLOCK_SIZE)
        if not block_data: # done with this file
            done = True
            fp.close()
            return 'SENT'
        else:
            if block_count in needed_blocks: # block needs sent
                result = send_block(block_data)
                #print('Sending block ' + str(block_count) + ' with length', len(block_data), 'result: ' + result.text)
        block_count = block_count + 1

    return 'OK'


#file_names = ['100K', '10K', '11MB', '120MB', '1KB', '1MB', '250K', '2MB', '30MB', '333K', '5MB', '768K', '7MB']
notallowed = ['recycle.bin', '.vscode', 'c:\\windows', '.config']

for dirpath, dirnames, filenames in os.walk(os.getcwd()):
    for f in filenames:
        file_name = os.path.join(dirpath, f)
        allowed = True
        for i in notallowed:
            if file_name.lower().find(i) is not -1:
                allowed = False

        if allowed:
            try:
                test = open(file_name, 'rb')
                test.close()
                #print('Committing: ', file_name)
                result = commit(file_name)
                print('Result:', result.status_code, '|', result.text, '|')

                blocks_needed = []
                result_json = ''
                if result.text == 'OK':
                    print('server has all the blocks for this file')
                else:
                    try:
                        result_json = json.loads(result.text)
                    except:
                        print('Unexpected response when trying commit()')
                        exit()

                if len(result_json) > 0:
                    for k, v in result_json.items():
                        blocks_needed.append(v)

                    #print('Blocks needed: ', blocks_needed)
                    send_file(file_name, blocks_needed)
                    result = commit(file_name)
                    #print('\nAfter sending blocks:\nResult:', result.status_code, result.text)
            except Exception as e:
                print('Error opening ' + file_name, e)
        else:
            print('not allowed: ' + file_name)
