# from pathlib import Path
import os
import sqlite3
import re
import sys

DB_FILE_EXTENSION = '.db'
CATALOG_BASE_PATH = 'D:\\Backups\\CATALOGS'
FILES_BASE_PATH = 'D:\\Backups\\FILES'
FILES_DIR_LAYERS = 4

KB = 1024
MB = 1024 * KB
BLOCK_SIZE = 4 * MB

def are_we_running_windows():
    if os.name == 'nt':
        return True
    else:
        return False
#
# Database Stuff
#

def get_database_file_path(client_id):
	# return X:\backups\catalogs\hostname\ for (hostname)
	return os.path.join(CATALOG_BASE_PATH, client_id)

def get_database_file_name(catalog_id):
	return catalog_id + DB_FILE_EXTENSION

# create and return a SQLite connection object
def open_client_catalog(client_id, catalog_id):
	db_dir = get_database_file_path(client_id)
	db_file_name = get_database_file_name(catalog_id)
	db_full_file_path = os.path.join(db_dir, db_file_name)
	if not os.path.exists(db_dir):
		print("Need to create the directory to hold catalog " + db_dir)
		os.makedirs(db_dir)

	db = sqlite3.connect(db_full_file_path)

	db.execute('''
			CREATE TABLE IF NOT EXISTS catalog (
			id INTEGER PRIMARY KEY,
			filename TEXT,
			ctime REAL,
			mtime REAL,
			size INT,
			blocklist_id INT
		)
		''')
	db.commit()

	db.execute('''
		CREATE TABLE IF NOT EXISTS blocklist (
				id INTEGER PRIMARY KEY,
			blocklist_id INT,
			series INT,
			md5 TEXT
		)
		''')
	db.commit()
	return db

# close the SQLite Connection object
def close_client_catalog(db):
    db.close()

# split a hash up into dir+filename:
#   (abcdef12345, 4) becomes ('\\a\\b\\c\\d\\', 'ef12345')
# md5 = 32 bytes, sha256 = 64 bytes
def file_path_parts_from_hash(hash):
	dest_dir = ''
	for i in range(0, FILES_DIR_LAYERS):
		dest_dir = os.path.join(dest_dir, hash[i])
	dest_file_name = hash[FILES_DIR_LAYERS:]

	return(dest_dir, dest_file_name)

# same thing, but return a str instead of tuple
def file_path_from_hash(hash):
	t = file_path_parts_from_hash(hash)
	return os.path.join(FILES_BASE_PATH, t[0], t[1])

# check if a hash exists in our file storage
def does_file_hash_exist(file_hash):
	name = os.path.join(file_path_from_hash(file_hash))
	if os.path.isfile(name):
		return True
	else:
		return False

def md5_hash_file_upload(fobj):
	hash_md5 = hashlib.md5()

	try:
		with fobj as f:
			for chunk in iter(lambda: f.read(4096), b""):
				hash_md5.update(chunk)
		return hash_md5.hexdigest()

	except:
		# let's do a real error capture/log here
		return "ERROR"

def get_blocklist_id(filename, client_id, catalog_id):
    db = open_client_catalog(client_id, catalog_id)
    cursor = db.cursor()
    cursor.execute(''' SELECT blocklist_id FROM catalog WHERE filename = ? ''', (filename,))
    blocklist_id = cursor.fetchone()
    if blocklist_id is None:
        return False
    else:
        close_client_catalog(db)
        return blocklist_id[0]

def get_hashes_for_block(block_id, client_id, catalog_id):
    db = open_client_catalog(client_id, catalog_id)
    cursor = db.cursor()
    cursor.execute(''' SELECT series, md5 FROM blocklist WHERE blocklist_id = ? ORDER BY series ASC''', (block_id,))
    hashes = cursor.fetchall()
    close_client_catalog(db)
    return hashes

def restore_file(filename, client_id, catalog_id, restore_path):
    id = get_blocklist_id(filename, client_id, catalog_id)
    if id is False:
        print("File '{}' not found.".format(filename,))
        return False
    else:
        print("Blocklist ID: " + str(id))

        hashes = get_hashes_for_block(id, client_id, catalog_id)
        print("Hashes: ")
        for i, h in hashes:
            print("Index: {}, Hash: {}, File: {}".format(i,h, file_path_from_hash(h)))

        # chop off the drive letter if it exists
        if re.search('^[A-Za-z]:', filename):
            # this is a windows path
            filename = filename[3:] # remove drive letter
            split_path = filename.split('\\')
        else:
            split_path = filename.split('/')
            # this is a linux path

        out_file_name = split_path[-1] # get the file name
        del split_path[-1] # remove it from the path
        full_restore_path = os.path.join(restore_path, *split_path) # re-assemble the path

        if not os.path.exists(full_restore_path):
            os.makedirs(full_restore_path) # create the new path

        out_file = open(os.path.join(full_restore_path, out_file_name), 'wb')

        print("Writing file to '{}'".format(out_file_name,))
        for i, h in hashes:
            print('.', end='')
            # open chunk
            in_chunk = open(file_path_from_hash(h), 'rb')
            data = in_chunk.read()
            # write chunk
            out_file.write(data)
            in_chunk.close()

        out_file.close()
        # close file

def restore_folder(foldername, client_id, catalog_id, restore_path):
    # restore a whole folder
    # pass something like: 'C:\Users\JoeSmith\Documents' to this function
    db = open_client_catalog(client_id, catalog_id)
    cursor = db.cursor()
    cursor.execute(''' SELECT blocklist_id, filename FROM catalog WHERE filename LIKE ? ''', ('%' + foldername + '%',))
    file_targets = cursor.fetchall()
    print("Rowcount = " + str(cursor.rowcount))
    close_client_catalog(db)
    for i, f in file_targets:
        #print("ID: {}, File: {}".format(i,f))
        restore_file(f, client, catalog, restore_path)
    return True

def getopts(argv):
    # collect command-line options into dictionary
    opts = {}
    while argv:
        if argv[0][0] == '-': # find "-name value" pairs
            opts[argv[0]] = argv[1] # dict key is "-name" arg
            argv = argv[2:]
        else:
            argv = argv[1:]
    return opts



#client_id = "ROBERTPC"
#catalog_id = "010112345678"
#restore_path = 'D:\\Restores'

def main():
    args = getopts(sys.argv)

    if len(args) != 4:
        print("\nInvalid arguments passed.\n")
        print("USAGE:\n")
        print("  python restore.py -client JeffB-laptop -catalog Dec2019Backup -restoreto F:\Documents -match Iventory.xlsx")
        exit()

    match = args['-match']
    client_id_arg = args['-client']
    catalog_id_arg = args['-catalog']
    restore_path = args['-restoreto']

    restore_folder(match, client_id_arg, catalog_id_arg, restore_path)

if __name__ == '__main__':
    main()
