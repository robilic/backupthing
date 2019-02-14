# backup-server-web.py
#
# simple web interface to backups
#
# robert vasquez
# Saginaw Control & Engineering

import os, sys
import requests
import socket
import datetime

import backuplib

client_id = socket.gethostname()
catalog_id = datetime.datetime.now().strftime('%Y%m%d%H%M%S')

#catalog_id = '20181215115959'
MAX_FILE_SIZE = 1000000000
backup_server_url = 'http://172.16.30.120:8080'
# 172.16.30.120 - RobertV
# useful for debugging - http://httpbin.org/post

# post_file(file_to_post)
#
#  This function will POST the file from the client to the backup server. The
#  backup server will hash/store the file on the filesystem.
#
#   file_to_check : path to file, 'C:\\DOS\\EDIT.COM'
#
def post_file(file_to_post):
    # this could potentially fail, but file could 'exist' from check_if_exists()
    f = file_to_post
    post_url = backup_server_url + '/upload/'
    #print("Attempting to POST " + f + " to: " + post_url)
    try:
        file_data = { 'file': open(f, 'rb') }
    except IOError as e:
        print("Error opening file '" + f + "'")
        print("I/O error({0}): {1}".format(e.errno, e.strerror))
        return 'ERROR'
    except: #handle other exceptions such as attribute errors
        print("Unexpected error:", sys.exc_info()[0])
        return ERROR
    try:
        r = requests.post(post_url, files=file_data)
        print("HTTP Response: " + r.text)
        return r.text
    except:
        print("Error connecting to backup server " + post_url)
        exit()

# check_if_exists(file_to_check)
#
#  This function will query the backup server to see if the file already exists
#  using the locally generated hash. It will also add the file to the catalog.
#  If the file DOES NOT EXIST, the server will return the hash of the file.
#
#   file_to_check : path to file, 'C:\\DOS\\EDIT.COM'
#
def check_if_exists(file_to_check):
    f = file_to_check
    fi = os.stat(f)
    if fi.st_size < MAX_FILE_SIZE: # don't try to back up files bigger than 1GB
        print('Checking if exists ' + f)
        file_hash = backuplib.md5_hash_file(f)
        post_url = backup_server_url + '/exists/' + file_hash
        absolute_file_path = os.path.abspath(f)
        metadata = [('client_id', client_id), ('catalog_id', catalog_id),
                    ('filename', absolute_file_path), ('ctime', fi.st_ctime),
                    ('mtime', fi.st_mtime), ('size', fi.st_size)]
        try:
            print('Making HTTP request')
            #print('POST:', post_url, metadata)
            r = requests.post(post_url, data=metadata, timeout=30)  # THIS LINE TAKES FOREVER
            return r.text
        except:
            print("Error connecting to backup server " + post_url)
            exit()
    else:
        print('WARNING: File ' + f + ' is huge, ' + str(fi.st_size) + ' bytes. Cannot back it up')
        return('ERROR')

# TODO:
# Write a main loop that just walks the file tree and uploads all files using HTTP
#

uploaded_size = 0
total_size = 0
file_count = 0

for dirpath, dirnames, filenames in os.walk(os.getcwd()):
    for f in filenames:
        for i in notallowed:
            if f.find(i) is not -1:
                print('Not backing up ' + f + ', restricted file')
            else:
                # combine the full directory path with the file name
                full_filename = os.path.join(dirpath, f)
                try:
                    fi = os.stat(full_filename)
                    total_size = total_size + fi.st_size
                    file_count = file_count + 1
                    resp = check_if_exists(full_filename)
                    if resp != 'ERROR':
                    #print("Result: " + resp)
                        if resp == backuplib.md5_hash_file(full_filename):
                            print('Uploading file ' + full_filename)
                            post_file(full_filename)
                            uploaded_size = uploaded_size + fi.st_size
                        else:
                            print('110 File ' + full_filename + ' already exists')
                except:
                    print('ERROR: cannot open file: ' + full_filename + ', ', sys.exc_info()[0])

print("Uploaded " + str(file_count) + " files. Uploaded size was " + str(uploaded_size) + ", total size was " + str(total_size) + ", savings of " + str(total_size - uploaded_size) + " bytes")
